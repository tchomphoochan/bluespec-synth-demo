/*
See original source: https://github.com/tchomphoochan/fpga-uart
*/

`default_nettype none

/*
8N1 UART transmitter.
Takes in only one byte at a time.
*/
module uart_tx #(
    parameter CLOCK_FREQ_HZ = 0,
    parameter BAUD_RATE = 0
) (
    // axi inputs
    input wire s_axis_aclk,
    input wire s_axis_aresetn,
    input wire s_axis_tvalid,
    input wire [7:0] s_axis_tdata,
    output logic s_axis_tready,
    // uart outputs
    output logic tx_bit
);

  /// ---
  /// cycle counter to generate baud rate
  /// ---

  localparam UART_CYCLES = CLOCK_FREQ_HZ / BAUD_RATE;
  localparam UART_CYCLES_BITS = $clog2(UART_CYCLES);

  logic [UART_CYCLES_BITS-1:0] uart_cycles;

  always_ff @(posedge s_axis_aclk) begin
    if (end_of_cycle || do_latch_data) uart_cycles <= 0;
    else uart_cycles <= uart_cycles + 1;
  end

  logic end_of_cycle;
  assign end_of_cycle = uart_cycles == UART_CYCLES - 1;

  /// ---
  /// UART state machine
  /// ---

  typedef enum {
    IDLE,
    START,
    DATA,
    STOP
  } state_t;

  state_t state = IDLE;
  always_ff @(posedge s_axis_aclk) begin
    state <= next_state;
    if (s_axis_aresetn == 0) state <= IDLE;
  end

  state_t next_state;
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (do_latch_data) next_state = START;
      end
      START: begin
        if (end_of_cycle) next_state = DATA;
      end
      DATA: begin
        if (end_of_cycle && data_counter == 7) next_state = STOP;
      end
      STOP: begin
        if (end_of_cycle) begin
          if (do_latch_data) next_state = START;
          else next_state = IDLE;
        end
      end
    endcase
  end

  /// ---
  /// DATA state counter
  /// only used when state == DATA; otherwise the value is meaningless
  /// resets to 0 upon entering DATA
  /// increments by one at the end of each uart cycle
  /// ---

  logic [3:0] data_counter;

  always_ff @(posedge s_axis_aclk) begin
    if (state != next_state && next_state == DATA) begin
      data_counter <= 0;
    end

    if (state == DATA && end_of_cycle) begin
      data_counter <= data_counter + 1;
    end
  end

  /// ---
  /// AXI ready signal
  /// ---

  assign s_axis_tready = state == IDLE || state == STOP && end_of_cycle;

  /// ---
  /// AXI txn logic: whether to latch data or not
  /// ---

  logic do_latch_data;
  assign do_latch_data = s_axis_tvalid && s_axis_tready;

  /// ---
  /// latches data when txn occurs or shifts right at the end of each data cycle
  /// ---

  logic [7:0] data_latched;

  always_ff @(posedge s_axis_aclk) begin
    if (do_latch_data) begin
      data_latched <= s_axis_tdata;
    end

    if (state == DATA && end_of_cycle) begin
      data_latched <= data_latched >> 1;
    end
  end

  /// ---
  /// output bit
  /// ---

  localparam IDLE_BIT = 1'b1;
  localparam START_BIT = 1'b0;
  localparam STOP_BIT = 1'b1;

  always_comb begin
    tx_bit = 0;
    case (state)
      IDLE:  tx_bit = IDLE_BIT;
      START: tx_bit = START_BIT;
      DATA:  tx_bit = data_latched[0];
      STOP:  tx_bit = STOP_BIT;
    endcase
  end

endmodule

`default_nettype wire