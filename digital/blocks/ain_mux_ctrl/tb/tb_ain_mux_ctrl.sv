// Digital-only check of ain_mux_ctrl: random channel requests and S/H track
// pulses, with assertions for the three mux-interface rules.
// Run: see integration/cosim/mux_diff2to1/README.md, step 3.
`timescale 1ns/1ps
module tb_ain_mux_ctrl;
    parameter int DEAD = 1, SETTLE = 2;   // override with xrun -defparam
    logic clk = 0, rst_n = 0, ch_sel = 0, sh_track = 0;
    logic en0, en1, ch_now, ch_ready;
    int   switches = 0, samples = 0, errors = 0;

    ain_mux_ctrl #(.DEAD(DEAD), .SETTLE(SETTLE)) dut (.*);

    always #41.667 clk = ~clk;   // 12 MHz

    // 1. never both channels on
    a_onehot: assert property (@(posedge clk) disable iff (!rst_n) !(en0 && en1))
        else begin errors++; $error("en0 and en1 both high"); end
    // 2. enables change only while the S/H holds
    a_hold: assert property (@(posedge clk) disable iff (!rst_n)
                             ($changed(en0) || $changed(en1)) |-> !$past(sh_track))
        else begin errors++; $error("enable changed during track"); end
    // 3. break-before-make: a channel turns on only after >= DEAD clocks with both off
    int off_clocks = 0;
    always @(posedge clk) off_clocks <= (!en0 && !en1) ? off_clocks + 1 : 0;
    a_bbm: assert property (@(posedge clk) disable iff (!rst_n)
                            ($rose(en0) || $rose(en1)) |-> $past(off_clocks) >= DEAD - 1 && $past(!en0 && !en1))
        else begin errors++; $error("break-before-make violated: %0d clocks off", $past(off_clocks) + 1); end
    // 5. ready only SETTLE clocks after the channel connected
    int on_clocks = 0;
    always @(posedge clk) on_clocks <= (en0 || en1) ? on_clocks + 1 : 0;
    a_settle: assert property (@(posedge clk) disable iff (!rst_n) ch_ready |-> on_clocks >= SETTLE)
        else begin errors++; $error("ch_ready after only %0d clocks on", on_clocks); end
    // ready implies the requested channel is the connected one, one-hot
    a_ready: assert property (@(posedge clk) disable iff (!rst_n)
                              ch_ready |-> (en0 ^ en1) && (en1 == ch_now))
        else begin errors++; $error("ch_ready with wrong enables"); end

    // Sequencer: change the request at random; track 2 clocks once ready.
    initial begin
        repeat (3) @(posedge clk);
        rst_n <= 1;
        repeat (400) begin
            @(posedge clk);
            if ($urandom_range(0, 7) == 0) begin ch_sel <= ~ch_sel; switches++; end
            if (ch_ready && !sh_track && $urandom_range(0, 3) == 0) begin
                sh_track <= 1;
                repeat (2) @(posedge clk);
                sh_track <= 0;
                samples++;
            end
        end
        if (errors == 0 && samples > 20 && switches > 20)
            $display("FORGE_TB_PASS ain_mux_ctrl DEAD=%0d SETTLE=%0d switches=%0d samples=%0d", DEAD, SETTLE, switches, samples);
        else
            $display("FORGE_TB_FAIL ain_mux_ctrl errors=%0d switches=%0d samples=%0d", errors, switches, samples);
        $finish;
    end
endmodule
