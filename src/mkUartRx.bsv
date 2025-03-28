/*
Simple Verilog wrapper for the UART-to-AXI4S receiver.
rx_bit is set by the outside world.
Bluespec user can call receive to raise tready high and consume the data
(which is made available to us through tvalid).

Technically this doesn't meet AXI4S specification because tvalid isn't supposed to depend on tready;
alas, we're working with Bluespec.
*/
interface UartRx;
  (* always_ready, always_enabled *)
  method Action                rxd(Bit#(1) rx_bit);

  method ActionValue#(Bit#(8)) receive;
endinterface

import "BVI" uart_rx =
module mkUartRx(UartRx);
  parameter CLOCK_FREQ_HZ = 125000000;
  parameter BAUD_RATE     = 115200;

  default_clock clk  (m_axis_aclk);
  default_reset rstn (m_axis_aresetn);

  method              rxd(rx_bit)                       enable((*inhigh*) _);
  method m_axis_tdata receive()    ready(m_axis_tvalid) enable(m_axis_tready);

  schedule (rxd, receive) CF (rxd, receive);
endmodule


/*
An example top-level module utilizing UartRx.
rx_bit comes from FPGA interface.
The received data is printed whenever possible, except every once in a while we stall.
*/
interface UartRxTest;
  (* always_ready, always_enabled *) method Action rxd(Bit#(1) rx_bit);
endinterface
module mkUartRxTest(UartRxTest);
  Reg#(Bit#(3)) counter <- mkReg(0);
  UartRx rx <- mkUartRx;

  rule tick;
    counter <= counter+1;
  endrule

  rule receive if (counter != 0);
    Bit#(8) data <- rx.receive();
    $write("%c", data);
  endrule

  method Action rxd(Bit#(1) rx_bit) = rx.rxd(rx_bit);
endmodule