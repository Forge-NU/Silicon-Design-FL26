`timescale 1ns/1ps
module tb;
  reg [3:0] count = 0;
  initial begin
    repeat (10) begin #5; count = count + 1; end
    if (count !== 10) $fatal(1, "Counter mismatch");
    $display("FORGE_RTL_PASS time=%0t count=%0d", $time, count);
    $finish;
  end
endmodule
