// note_control.v
// Picks ONE note to play from the 7 "key held" lines (monophonic piano).
//   key_down[0] = Do ... key_down[6] = Si   (1 = held)
//   active_note = 0 silent, 1..7 = Do..Si   (= bit index + 1)
// Rules: the newest pressed key wins (lowest wins if pressed in the same cycle).
//        If the playing key is released, fall back to the lowest key still held.

module note_control (
    input            clk,
    input            reset,          // active-high, synchronous
    input      [6:0] key_down,       // keys currently held
    output reg [2:0] active_note     // note to play
);

    reg  [6:0] prev_down;                          // key_down from last cycle
    wire [6:0] pressed = key_down & ~prev_down;    // keys that just went down (0 -> 1)

    // Lowest set bit -> note number (1..7); 0 if no bits set
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

    // Is the note currently playing still being held
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
            default: active_held = 1'b0;           // silent: nothing to hold
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            prev_down   <= 7'd0;
            active_note <= 3'd0;
        end
        else begin
            prev_down <= key_down;                 // remember for edge detection
            if (pressed != 7'd0)
                active_note <= lowest_note(pressed);   // a new press takes over
            else if (!active_held)
                active_note <= lowest_note(key_down);  // released: fall back, or 0 if none held
            // otherwise keep playing the same note
        end
    end

endmodule
