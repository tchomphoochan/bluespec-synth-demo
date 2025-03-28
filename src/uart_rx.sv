/*
See original source: https://github.com/tchomphoochan/fpga-uart
*/

`default_nettype none

/*
8N1 UART receiver.
Takes in only one byte at a time.
*/
module uart_rx #(
    parameter CLOCK_FREQ_HZ = 0,
    parameter BAUD_RATE = 0
) (
    // uart inputs
    input wire rx_bit,
    // axi master interface
    input wire m_axis_aclk,
    input wire m_axis_aresetn,
    output logic m_axis_tvalid,
    output logic [7:0] m_axis_tdata,
    input wire m_axis_tready
);

  /// ---
  /// state machine
  /// ---

  localparam START_BIT = 1'b0;
  localparam STOP_BIT = 1'b1;

  typedef enum {
    IDLE,
    START,
    DATA,
    STOP,
    TRANSFER
  } state_t;

  state_t state = IDLE;
  state_t next_state;

  always_ff @(posedge m_axis_aclk) begin
    state <= next_state;
    if (m_axis_aresetn == 0) state <= IDLE;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (rx_bit == START_BIT) next_state = START;
        else next_state = IDLE;
      end
      START: begin
        // must confirm that the start bit is not spurrious
        if (half_cycle && rx_bit != START_BIT) next_state = IDLE;
        if (end_of_cycle) next_state = DATA;
      end
      DATA: begin
        if (end_of_cycle && data_counter == 7) next_state = STOP;
      end
      STOP: begin
        // must confirm that the stop bit is correct
        if (half_cycle && rx_bit != STOP_BIT) next_state = IDLE;
        if (end_of_cycle) begin
          if (m_axis_tready)
            next_state = IDLE;  // can send data immediately, no need to wait at TRANSER
          else next_state = TRANSFER;  // can't send right now, so need to buffer output at TRANSFER
        end
      end
      TRANSFER: begin
        // do not move back to IDLE until a txn has taken place
        if (m_axis_tready && m_axis_tvalid) next_state = IDLE;
      end
    endcase
  end

  /// ---
  /// cycle counter to generate baud rate
  /// ---

  localparam UART_CYCLES = CLOCK_FREQ_HZ / BAUD_RATE;
  localparam UART_HALF_CYCLES = UART_CYCLES / 2;
  localparam UART_CYCLES_BITS = $clog2(UART_CYCLES);

  logic [UART_CYCLES_BITS-1:0] uart_cycles;

  always_ff @(posedge m_axis_aclk) begin
    // special case; we want to make sure we counted the first START_BIT we saw
    if (state == IDLE && next_state == START) uart_cycles <= 1;
    else if (end_of_cycle) uart_cycles <= 0;
    else uart_cycles <= uart_cycles + 1;
  end

  logic half_cycle;
  assign half_cycle = uart_cycles == UART_HALF_CYCLES;

  logic end_of_cycle;
  assign end_of_cycle = uart_cycles == UART_CYCLES - 1;

  /// ---
  /// DATA state counter
  /// only used when state == DATA; otherwise the value is meaningless
  /// resets to 0 upon entering DATA
  /// increments by one at the end of each uart cycle
  /// ---

  logic [3:0] data_counter;

  always_ff @(posedge m_axis_aclk) begin
    if (state != next_state && next_state == DATA) begin
      data_counter <= 0;
    end

    if (state == DATA && end_of_cycle) begin
      data_counter <= data_counter + 1;
    end
  end

  /// ---
  /// latch data in DATA state at half period
  /// ---

  logic [7:0] data_latched;

  always_ff @(posedge m_axis_aclk) begin
    if (state == DATA && half_cycle) data_latched <= {rx_bit, data_latched[7:1]};
  end

  /// ---
  /// output
  /// ---

  assign m_axis_tvalid = state == STOP && end_of_cycle || state == TRANSFER;
  assign m_axis_tdata  = data_latched;

endmodule

`default_nettype wire