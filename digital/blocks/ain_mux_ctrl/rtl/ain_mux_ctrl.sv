// ain_mux_ctrl: drives en0/en1 of the analog mux Matt_Mux/muxDiff2to1.
//
// Rules from the mux spec that the analog cell leaves to the controller:
//   - en0 and en1 are never high together (break-before-make, >= DEAD clocks
//     with both off between channels);
//   - an enable changes only while the S/H holds (sh_track low);
//   - after a channel connects, ch_ready waits SETTLE clocks so the source
//     and mux output have settled before the sequencer starts a sample.
//
// Drive sh_track high for the whole S/H busy window, from the start of any
// precharge through the end of tracking, so a channel never switches right
// before a track. ch_ready is low while a different channel is requested.
// ch_sel and sh_track must be synchronous to clk.
module ain_mux_ctrl #(
    parameter int DEAD   = 1,   // clocks with both channels off on a change, >= 1
    parameter int SETTLE = 2    // clocks after connect before ch_ready
) (
    input  logic clk,
    input  logic rst_n,
    input  logic ch_sel,    // requested channel: 0 = T1 on-die sensor, 1 = T2 NTC bridge
    input  logic sh_track,  // 1 while the S/H precharges or tracks; enables are frozen then
    output logic en0,       // to muxDiff2to1 en0 (1.8 V logic)
    output logic en1,       // to muxDiff2to1 en1
    output logic ch_now,    // channel connected (valid when ch_ready)
    output logic ch_ready   // requested channel connected and settled: safe to start a sample
);
    localparam int CW = $clog2((DEAD > SETTLE ? DEAD : SETTLE) + 1) + 1;

    typedef enum logic {S_OFF, S_ON} state_t;
    state_t        state;
    logic [CW-1:0] cnt;

    initial begin
        assert (DEAD >= 1) else $error("ain_mux_ctrl: DEAD must be >= 1");
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state  <= S_OFF;
            cnt    <= '0;
            ch_now <= 1'b0;
            en0    <= 1'b0;
            en1    <= 1'b0;
        end else begin
            case (state)
                S_ON: begin
                    if (ch_sel != ch_now && !sh_track) begin
                        en0   <= 1'b0;          // break first
                        en1   <= 1'b0;
                        cnt   <= '0;
                        state <= S_OFF;
                    end else if (cnt != CW'(SETTLE)) begin
                        cnt <= cnt + 1'b1;
                    end
                end
                S_OFF: begin
                    if (cnt + 1'b1 >= CW'(DEAD) && !sh_track) begin
                        ch_now <= ch_sel;       // then make
                        en0    <= !ch_sel;
                        en1    <= ch_sel;
                        cnt    <= '0;
                        state  <= S_ON;
                    end else if (cnt + 1'b1 < CW'(DEAD)) begin
                        cnt <= cnt + 1'b1;
                    end
                end
                default: state <= S_OFF;
            endcase
        end
    end

    assign ch_ready = (state == S_ON) && (cnt == CW'(SETTLE)) && (ch_sel == ch_now);
endmodule
