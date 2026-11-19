// note_control.v
// Turns the 7 "key held" lines into ONE active note (monophonic piano).
//
// Interface contract (shared with Milestone 2 keyboard input):
//   key_down[0] = Do (C4)   key_down[4] = Sol (G4)
//   key_down[1] = Re (D4)   key_down[5] = La  (A4)
//   key_down[2] = Mi (E4)   key_down[6] = Si  (B4)
//   key_down[3] = Fa (F4)
//   active_note = 0 -> silent, 1..7 -> Do..Si   (active_note = index + 1)
//
// Rule: the most recently pressed key wins. If that key is released while
// others are still held, fall back to the lowest held key.

module note_control (
    input            clk,
    input            reset,          // active-high, synchronous
    input      [6:0] key_down,       // level: 1 = key held
    output reg [2:0] active_note     // 0 = none, 1..7 = Do..Si
);

    reg  [6:0] prev_down;
    wire [6:0] pressed = key_down & ~prev_down;   // rising edges this cycle

    // lowest set bit -> note number (1..7), 0 if none
    function [2:0] lowest_note;
        input [6:0] v;
        begin
            if      (v[0]) lowest_note = 3'd1;
            else if (v[1]) lowest_note = 3'd2;
            else if (v[2]) lowest_note = 3'd3;
            else if (v[3]) lowest_note = 3'd4;
            else if (v[4]) lowest_note = 3'd5;
            else if (v[5]) lowest_note = 3'd6;
            else if (v[6]) lowest_note = 3'd7;
            else           lowest_note = 3'd0;
        end
    endfunction

    // is the currently active note still held
    reg active_held;
    always @(*) begin
        case (active_note)
            3'd1:    active_held = key_down[0];
            3'd2:    active_held = key_down[1];
            3'd3:    active_held = key_down[2];
            3'd4:    active_held = key_down[3];
            3'd5:    active_held = key_down[4];
            3'd6:    active_held = key_down[5];
            3'd7:    active_held = key_down[6];
            default: active_held = 1'b0;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            prev_down   <= 7'd0;
            active_note <= 3'd0;
        end
        else begin
            prev_down <= key_down;
            if (pressed != 7'd0)
                active_note <= lowest_note(pressed);   // new press wins
            else if (!active_held)
                active_note <= lowest_note(key_down);  // released -> fall back / silence
        end
    end

endmodule
