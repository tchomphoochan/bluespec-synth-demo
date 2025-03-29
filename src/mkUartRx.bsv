/*
Simple Verilog wrapper for the UART-to-AXI4S receiver.
rx_bit is set by the outside world.
Bluespec user can call receive to raise tready high and consume the data
(which is made available to us through tvalid).

Technically this doesn't meet AXI4S specification because tvalid isn't supposed to depend on tready;
alas, we're working with Bluespec.
*/
interface UartRx;
  method ActionValue#(Bit#(8)) receive;
endinterface

import "BVI" uart_rx =
module mkUartRx#(Bit#(1) uart_rxd)(UartRx);
  parameter CLOCK_FREQ_HZ = 125000000;
  parameter BAUD_RATE     = 115200;

  default_clock clk  (m_axis_aclk);
  default_reset rstn (m_axis_aresetn);

  port rx_bit = uart_rxd;
  method m_axis_tdata receive()    ready(m_axis_tvalid) enable(m_axis_tready);

  schedule (receive) CF (receive);
endmodule


/*
An example top-level module utilizing UartRx.
rx_bit comes from FPGA interface.
The received data is printed whenever possible, except every once in a while we stall.
*/
interface UartRxTest;
endinterface
module mkUartRxTest#(Bit#(1) uart_rxd)(UartRxTest);
  Reg#(Bit#(3)) counter <- mkReg(0);
  UartRx rx <- mkUartRx(uart_rxd);

  rule tick;
    counter <= counter+1;
  endrule

  rule receive if (counter != 0);
    Bit#(8) data <- rx.receive();
    $write("%c", data);
  endrule
endmodule