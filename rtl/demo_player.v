// demo_player.v
// Test note source: when enabled, plays "Twinkle Twinkle Little Star" once
// through (42 notes), then starts again from the beginning.
// Output has the same format as the switches (bit 0 = Do ... bit 6 = Si),
// so the rest of the design can't tell demo notes from switch notes.
//
// Melody (C D E F G A = Do Re Mi Fa Sol La, "-" = held for 2 beats):
//   C C G G A A G-  |  F F E E D D C-     Twinkle twinkle little star...
//   G G F F E E D-  |  G G F F E E D-     Up above the world so high...
//   C C G G A A G-  |  F F E E D D C-     Twinkle twinkle little star...
//
// Timing (one beat = 0.5 s, i.e. 120 BPM):
//   short note : ON_CYCLES held                        = 0.4 s, then 0.1 s gap
//   long note  : 2 x ON_CYCLES + GAP_CYCLES held       = 0.9 s, then 0.1 s gap
// The gap between notes lets repeated notes (C C, G G ...) sound separate.

module demo_player #(
    parameter [25:0] ON_CYCLES  = 26'd20000000,  // 20M x 20 ns = 0.4 s
    parameter [25:0] GAP_CYCLES = 26'd5000000    //  5M x 20 ns = 0.1 s
)(                                               // (26 bits: a long note is 45M cycles)
    input            clk,       // 50 MHz clock
    input            reset,     // active-high
    input            enable,    // 1 = demo running (SW9)
    output reg [6:0] key_down   // one key held, or none during the gap
);

    localparam [5:0] LAST_STEP = 6'd41;          // 42 notes: steps 0..41

    reg [25:0] timer;   // clock cycles elapsed in the current note or gap
    reg [5:0]  step;    // position in the song (0..41)
    reg        gap;     // 0 = note held, 1 = silent gap

    reg [2:0]  idx;     // note at this step: 0 = Do ... 6 = Si
    reg        long;    // 1 = this note lasts 2 beats

    // song ROM: step -> (note, long) 
    always @(*) begin
        long = 1'b0;
        case (step)
            // line 1: C C G G A A G-
            6'd0:  idx = 3'd0;
            6'd1:  idx = 3'd0;
            6'd2:  idx = 3'd4;
            6'd3:  idx = 3'd4;
            6'd4:  idx = 3'd5;
            6'd5:  idx = 3'd5;
            6'd6:  begin idx = 3'd4; long = 1'b1; end
            // line 2: F F E E D D C-
            6'd7:  idx = 3'd3;
            6'd8:  idx = 3'd3;
            6'd9:  idx = 3'd2;
            6'd10: idx = 3'd2;
            6'd11: idx = 3'd1;
            6'd12: idx = 3'd1;
            6'd13: begin idx = 3'd0; long = 1'b1; end
            // line 3: G G F F E E D-
            6'd14: idx = 3'd4;
            6'd15: idx = 3'd4;
            6'd16: idx = 3'd3;
            6'd17: idx = 3'd3;
            6'd18: idx = 3'd2;
            6'd19: idx = 3'd2;
            6'd20: begin idx = 3'd1; long = 1'b1; end
            // line 4: G G F F E E D-
            6'd21: idx = 3'd4;
            6'd22: idx = 3'd4;
            6'd23: idx = 3'd3;
            6'd24: idx = 3'd3;
            6'd25: idx = 3'd2;
            6'd26: idx = 3'd2;
            6'd27: begin idx = 3'd1; long = 1'b1; end
            // line 5: C C G G A A G-
            6'd28: idx = 3'd0;
            6'd29: idx = 3'd0;
            6'd30: idx = 3'd4;
            6'd31: idx = 3'd4;
            6'd32: idx = 3'd5;
            6'd33: idx = 3'd5;
            6'd34: begin idx = 3'd4; long = 1'b1; end
            // line 6: F F E E D D C-
            6'd35: idx = 3'd3;
            6'd36: idx = 3'd3;
            6'd37: idx = 3'd2;
            6'd38: idx = 3'd2;
            6'd39: idx = 3'd1;
            6'd40: idx = 3'd1;
            6'd41: begin idx = 3'd0; long = 1'b1; end
            default: idx = 3'd0;
        endcase
    end

    // How long the current note is held
    reg [25:0] note_cycles;
    always @(*) begin
        if (long)
            note_cycles = ON_CYCLES + ON_CYCLES + GAP_CYCLES;   // 2 beats minus the gap
        else
            note_cycles = ON_CYCLES;                            // 1 beat minus the gap
    end

    // sequencer
    always @(posedge clk) begin
        // Reset or demo off: go back to the start of the song
        if (reset || !enable) begin
            timer <= 26'd0;
            step  <= 6'd0;
            gap   <= 1'b0;
        end
        // Note finished -> start the gap
        else if (!gap && timer == note_cycles - 26'd1) begin
            timer <= 26'd0;
            gap   <= 1'b1;
        end
        // Gap finished -> next note (after the last note, restart the song)
        else if (gap && timer == GAP_CYCLES - 26'd1) begin
            timer <= 26'd0;
            gap   <= 1'b0;
            if (step == LAST_STEP)
                step <= 6'd0;
            else
                step <= step + 6'd1;
        end
        // Otherwise keep counting
        else begin
            timer <= timer + 26'd1;
        end
    end

    // Hold only the key for the current step; release all keys in the gap or when off
    always @(*) begin
        key_down = 7'd0;            // default (also prevents a latch)
        if (enable && !gap)
            key_down[idx] = 1'b1;   // e.g. idx = 4 -> 0010000 (Sol)
    end

endmodule
