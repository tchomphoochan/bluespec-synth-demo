/*
Simple Verilog wrapper for the AXI4S-to-UART transmitter.
Bluespec user can call send which raises tvalid high.
User can only call send when tready is high.
*/
interface UartTx;
  (* always_ready *) method Action  send(Bit#(8) data);
  (* always_ready *) method Bit#(1) txd;
endinterface

import "BVI" uart_tx =
module mkUartTx(UartTx);
  parameter CLOCK_FREQ_HZ = 125000000;
  parameter BAUD_RATE     = 115200;

  default_clock clk  (s_axis_aclk);
  default_reset rstn (s_axis_aresetn);

  // interface for bsv to enqueue to the internal fifo
  // method is ready when the verilog code says it's ready
  // when BSV runs (enables) the method, it asserts s_axis_tvalid.

  // note that this is technically illegal per axi standard:
  // BSV's output (to verilog) tvalid depended combinationally on input tready.
  // potential for deadlock/livelock if the verilog implementation doesn't
  // do a good job at asserting tready as often as possible.

  // MAYBE we could charitably interpret that bsv always tries to assert enable
  // whenever a rule MIGHT fire (whether it can actually fire or not is another story),
  // and that the internal module is responsible for only transacting if it asserted tready.
  // this is unlikely though. this is the key reason why bluespec will never be as performant as verilog.
  // its semantics is the inverse of what the rest of the fpga world wants.
  method        send(s_axis_tdata) enable(s_axis_tvalid) ready(s_axis_tready);
  method tx_bit txd;

  schedule (txd, send) CF (txd, send);
endmodule


/*
An example top-level module utilizing UartTx.
It tries to send the counter value whenever possible.
The UART output bit is exposed to FPGA interface.
*/
interface UartTxTest;
  (* always_ready *) method Bit#(1) txd;
endinterface

module mkUartTxTest(UartTxTest);
  Reg#(Bit#(8)) counter <- mkReg(0);
  UartTx tx             <- mkUartTx;

  rule tick;
    counter <= counter+1;
  endrule

  rule send;
    tx.send(counter);
  endrule

  method Bit#(1) txd = tx.txd;
endmodule
