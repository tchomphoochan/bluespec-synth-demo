interface LedCtrl#(numeric type period);
  (* always_ready *) method Action switchDirection;
  (* always_enabled *) method Bit#(8) led;
endinterface


(* always_ready = "tickCycle, updateLedVals, switchDirection",
   always_enabled = "tickCycle, updateLedVals, switchDirection" *)
module mkLedCtrl(LedCtrl#(period));
  Reg#(Bit#(TLog#(period))) cycle <- mkReg(0);
  Reg#(Bool) goingUp <- mkReg(False);
  Reg#(Bit#(8)) ledVals <- mkReg(8'b0000_0001);

  (* fire_when_enabled *)
  rule tickCycle;
    cycle <= cycle == fromInteger(valueOf(period)) ? 0 : cycle+1;
  endrule

  (* fire_when_enabled *)
  rule updateLedVals;
    if (goingUp) begin
      ledVals <= ledVals == 8'b1000_0000 ? 8'b0000_0001 : (ledVals << 1);
    end else begin
      ledVals <= ledVals == 8'b0000_0001 ? 8'b1000_0000 : (ledVals >> 1);
    end
  endrule

  method Action switchDirection;
    goingUp <= !goingUp;
  endmethod

  method Bit#(8) led = ledVals;
endmodule


/*
For test syntheses
*/
module mkLedCtrlDefault(LedCtrl#(1000));
  LedCtrl#(1000) ledCtrl <- mkLedCtrl;
  return ledCtrl;
endmodule