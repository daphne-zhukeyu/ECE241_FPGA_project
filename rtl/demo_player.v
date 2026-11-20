// demo_player.v
// Test note source: when enabled, "presses" Do, Re, Mi ... Si one at a time
// (0.4 s each, 0.1 s silent gap between notes), then loops back to Do.
// Output has the same format as the switches (bit 0 = Do ... bit 6 = Si),
// so the rest of the design can't tell demo notes from switch notes.

module demo_player #(
    parameter [24:0] ON_CYCLES  = 25'd20000000,  // note length: 20M x 20 ns = 0.4 s
    parameter [24:0] GAP_CYCLES = 25'd5000000    // gap length:   5M x 20 ns = 0.1 s
)(                                               // (25 bits: 20M needs more than 24 bits)
    input            clk,       // 50 MHz clock
    input            reset,     // active-high
    input            enable,    // 1 = demo running (SW9)
    output reg [6:0] key_down   // one key held, or none during the gap
);

    reg [24:0] timer;   // clock cycles elapsed in the current note or gap
    reg [2:0]  idx;     // current note: 0 = Do ... 6 = Si
    reg        gap;     // 0 = note held, 1 = silent gap

    always @(posedge clk) begin
        // Reset or demo off: go back to Do so the scale restarts cleanly
        if (reset || !enable) begin
            timer <= 25'd0;
            idx   <= 3'd0;
            gap   <= 1'b0;
        end
        // Note finished -> start the gap
        else if (!gap && timer == ON_CYCLES - 25'd1) begin
            timer <= 25'd0;
            gap   <= 1'b1;
        end
        // Gap finished -> next note (Si wraps around to Do)
        else if (gap && timer == GAP_CYCLES - 25'd1) begin
            timer <= 25'd0;
            gap   <= 1'b0;
            if (idx == 3'd6)
                idx <= 3'd0;
            else
                idx <= idx + 3'd1;
        end
        // Otherwise keep counting
        else begin
            timer <= timer + 25'd1;
        end
    end

    // Hold only the key selected by idx; release all keys in the gap or when off
    always @(*) begin
        key_down = 7'd0;            // default (also prevents a latch)
        if (enable && !gap)
            key_down[idx] = 1'b1;   // e.g. idx = 2 -> 0000100 (Mi)
    end

endmodule
