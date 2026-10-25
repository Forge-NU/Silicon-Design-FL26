// Paste into the "functional" view of cell inv_stim (docs/ams-cosim.md, Part B).
// Digital stimulus and checker for the schematic testbench inv_ams_tb:
// drives the inverter input a and checks its output y after each change.
`timescale 1ns/1ps

module inv_stim (a, y);
  output a;
  input  y;

  reg a_drv = 1'b0;
  assign a = a_drv;   // drive through a net; ports touching analog must be nets
  integer checks = 0, errors = 0;

  task drive_and_check(input value);
    begin
      a_drv = value;
      #4;                                // let the analog output settle
      checks = checks + 1;
      if (y !== ~value) begin
        errors = errors + 1;
        $display("inv_stim: FAIL at %0t: a=%b y=%b", $time, value, y);
      end
    end
  endtask

  initial begin
    #2;
    repeat (4) begin
      drive_and_check(1'b1);
      drive_and_check(1'b0);
    end
    if (errors == 0) $display("inv_stim: PASS checks=%0d", checks);
    else $display("inv_stim: FAIL errors=%0d of %0d", errors, checks);
  end
endmodule
