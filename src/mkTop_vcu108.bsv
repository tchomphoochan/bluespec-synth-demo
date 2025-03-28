import Clocks::*;
import mkLedCtrl::*;
// import mkIBUFGDS::*;
import XilinxCells::*;

typedef TDiv#(125_000_000, 10) Period;

(* always_enabled, always_ready *)
interface Top_vcu108;
  (* prefix = "", result = "btn" *)
  method Action btn;
  (* prefix = "", result = "led" *)
  method Bit#(8) led;
endinterface

(* no_default_clock, no_default_reset, clock_prefix="", reset_prefix="" *)
module mkTop_vcu108#(
  Clock clk_125mhz_p,
  Clock clk_125mhz_n,
  Reset rst // active high
)(Top_vcu108);

  // My own version:
  // ClockGenIfc sys_clk_import <- mkIBUFGDS(clk_125mhz_p, clk_125mhz_n);
  // Clock sys_clk = sys_clk_import.gen_clk;

  // Alternatively, use bsc-contrib's library
  let params = IBUFGDSParams {
    capacitance:             "DONT_CARE",
    diff_term:               "FALSE",
    ibuf_delay_value:        "0",
    ibuf_low_pwr:            "FALSE",
    iostandard:              "DEFAULT"
  };
  Clock sys_clk <- mkClockIBUFGDS(params, clk_125mhz_p, clk_125mhz_n);

  Reset sys_rst <- mkResetInverter(rst, clocked_by sys_clk); // but bsc wants active low
  LedCtrl#(Period) ledCtrl <- mkLedCtrl(clocked_by sys_clk, reset_by sys_rst);

  method Action btn = ledCtrl.switchDirection;
  method Bit#(8) led = ledCtrl.led;
endmodule
