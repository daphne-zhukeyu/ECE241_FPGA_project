// demo_player.v
// Test note-event source for Milestone 1: plays Do Re Mi Fa Sol La Si
// (each note ON for ~0.4 s, then a ~0.1 s gap), then repeats.
// Output uses the same key_down[6:0] format as the switches / keyboard.

module demo_player #(
    parameter [24:0] ON_CYCLES  = 25'd20000000,  // 0.4 s @ 50 MHz
    parameter [24:0] GAP_CYCLES = 25'd5000000    // 0.1 s @ 50 MHz
)(
    input            clk,
    input            reset,
    input            enable,
    output reg [6:0] key_down
);

    reg [24:0] timer;
    reg [2:0]  idx;      // 0..6
    reg        gap;      // 1 = silent gap between notes

    always @(posedge clk) begin
        if (reset || !enable) begin
            timer <= 25'd0;
            idx   <= 3'd0;
            gap   <= 1'b0;
        end
        else if (!gap && timer == ON_CYCLES - 25'd1) begin
            timer <= 25'd0;
            gap   <= 1'b1;
        end
        else if (gap && timer == GAP_CYCLES - 25'd1) begin
            timer <= 25'd0;
            gap   <= 1'b0;
            if (idx == 3'd6)
                idx <= 3'd0;
            else
                idx <= idx + 3'd1;
        end
        else begin
            timer <= timer + 25'd1;
        end
    end

    always @(*) begin
        key_down = 7'd0;
        if (enable && !gap)
            key_down[idx] = 1'b1;
    end

endmodule
