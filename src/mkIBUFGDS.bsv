import Clocks::*;

import "BVI" IBUFGDS =
module mkIBUFGDS#(Clock clk_p, Clock clk_n)(ClockGenIfc);
  default_clock no_clock;
  default_reset no_reset;

  parameter DIFF_TERM    = "FALSE";
  parameter IBUF_LOW_PWR = "FALSE";

  input_clock  clk_p  (I)  = clk_p;
  input_clock  clk_n  (IB) = clk_n;
  output_clock gen_clk (O);

  path(I, O);
  path(IB, O);

  same_family(clk_p, gen_clk);
endmodule