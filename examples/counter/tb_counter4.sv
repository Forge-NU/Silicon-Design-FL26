`timescale 1ns/1ps
module tb_counter4;
  reg clk=0, rst_n=0, en=0;
  wire [3:0] count;
  reg [3:0] expected=0;
  integer checks=0;
  counter4 dut(.clk(clk), .rst_n(rst_n), .en(en), .count(count));
  always #5 clk=~clk;
  task tick(input bit reset_value, input bit enable_value);
    begin
      @(negedge clk); rst_n=reset_value; en=enable_value;
      @(posedge clk);
      if (!reset_value) expected=0;
      else if (enable_value) expected=expected+1'b1;
      #1;
      if (count !== expected)
        $fatal(1,"FAIL check=%0d expected=%0d actual=%0d",checks,expected,count);
      checks=checks+1;
    end
  endtask
  initial begin
    tick(0,0);
    repeat(20) tick(1,1); // Includes wraparound.
    repeat(3) tick(1,0);  // Hold.
    tick(0,1);           // Reset overrides enable.
    tick(1,1);
    $display("FORGE_COUNTER_PASS checks=%0d",checks);
    $finish;
  end
  initial begin #1000; $fatal(1,"Watchdog expired"); end
endmodule
