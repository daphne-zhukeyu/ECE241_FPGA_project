// demo_player.v
// Test note source that plays one of two songs, then loops it:
//   song_sel = 0 : "Twinkle Twinkle Little Star"  (42 notes, SW9)
//   song_sel = 1 : "Ode to Joy"                    (62 notes, SW8)
// Output has the same format as the switches (bit 0 = Do ... bit 6 = Si),
// so the rest of the design can't tell demo notes from switch notes.
//
// Timing (120 BPM): note lengths are stored in eighth notes (1 eighth = 0.25 s).
//   A note of length L sounds for L x 0.25 s - 0.1 s, then a 0.1 s silent gap,
//   so repeated notes (C C, E E ...) are heard separately.
//     eighth (1) = 0.15 s on   quarter (2) = 0.4 s on
//     dotted quarter (3) = 0.65 s on   half (4) = 0.9 s on

module demo_player #(
    parameter [25:0] EIGHTH_CYCLES = 26'd12500000,  // 12.5M x 20 ns = 0.25 s
    parameter [25:0] GAP_CYCLES    = 26'd5000000    //  5M  x 20 ns = 0.1 s
)(                                                  // (26 bits: a half note is 45M cycles)
    input            clk,       // 50 MHz clock
    input            reset,     // active-high
    input            enable,    // 1 = demo running
    input            song_sel,  // 0 = Twinkle Twinkle, 1 = Ode to Joy
    output reg [6:0] key_down   // one key held, or none during the gap
);

    // Note names -> key index, and lengths in eighth notes
    localparam [2:0] C = 3'd0, D = 3'd1, E = 3'd2, F = 3'd3, G = 3'd4, A = 3'd5;
    localparam [2:0] N8 = 3'd1, N4 = 3'd2, N4D = 3'd3, N2 = 3'd4;   // eighth, quarter, dotted quarter, half

    reg [25:0] timer;     // clock cycles elapsed in the current note or gap
    reg [5:0]  step;      // position in the song
    reg        gap;       // 0 = note held, 1 = silent gap
    reg        cur_sel;   // song currently being played (to detect a change)

    reg [2:0]  idx;       // note at this step: 0 = Do ... 6 = Si
    reg [2:0]  len;       // length at this step, in eighth notes
    reg [5:0]  last_step; // index of the song's final note

    // ---------------- song ROMs: (song, step) -> (note, length) ----------------
    always @(*) begin
        idx = C;
        len = N4;
        if (!song_sel) begin
            // ---- Twinkle Twinkle Little Star ----
            last_step = 6'd41;
            case (step)
                // C C G G A A G-
                6'd0:  idx = C;  6'd1:  idx = C;  6'd2:  idx = G;  6'd3:  idx = G;
                6'd4:  idx = A;  6'd5:  idx = A;  6'd6:  begin idx = G; len = N2; end
                // F F E E D D C-
                6'd7:  idx = F;  6'd8:  idx = F;  6'd9:  idx = E;  6'd10: idx = E;
                6'd11: idx = D;  6'd12: idx = D;  6'd13: begin idx = C; len = N2; end
                // G G F F E E D-
                6'd14: idx = G;  6'd15: idx = G;  6'd16: idx = F;  6'd17: idx = F;
                6'd18: idx = E;  6'd19: idx = E;  6'd20: begin idx = D; len = N2; end
                // G G F F E E D-
                6'd21: idx = G;  6'd22: idx = G;  6'd23: idx = F;  6'd24: idx = F;
                6'd25: idx = E;  6'd26: idx = E;  6'd27: begin idx = D; len = N2; end
                // C C G G A A G-
                6'd28: idx = C;  6'd29: idx = C;  6'd30: idx = G;  6'd31: idx = G;
                6'd32: idx = A;  6'd33: idx = A;  6'd34: begin idx = G; len = N2; end
                // F F E E D D C-
                6'd35: idx = F;  6'd36: idx = F;  6'd37: idx = E;  6'd38: idx = E;
                6'd39: idx = D;  6'd40: idx = D;  6'd41: begin idx = C; len = N2; end
                default: idx = C;
            endcase
        end
        else begin
            // ---- Ode to Joy (all quarter notes unless marked) ----
            last_step = 6'd61;
            case (step)
                // E E F G | G F E D | C C D E | E. D D-
                6'd0:  idx = E;  6'd1:  idx = E;  6'd2:  idx = F;  6'd3:  idx = G;
                6'd4:  idx = G;  6'd5:  idx = F;  6'd6:  idx = E;  6'd7:  idx = D;
                6'd8:  idx = C;  6'd9:  idx = C;  6'd10: idx = D;  6'd11: idx = E;
                6'd12: begin idx = E; len = N4D; end
                6'd13: begin idx = D; len = N8;  end
                6'd14: begin idx = D; len = N2;  end
                // E E F G | G F E D | C C D E | D. C C-
                6'd15: idx = E;  6'd16: idx = E;  6'd17: idx = F;  6'd18: idx = G;
                6'd19: idx = G;  6'd20: idx = F;  6'd21: idx = E;  6'd22: idx = D;
                6'd23: idx = C;  6'd24: idx = C;  6'd25: idx = D;  6'd26: idx = E;
                6'd27: begin idx = D; len = N4D; end
                6'd28: begin idx = C; len = N8;  end
                6'd29: begin idx = C; len = N2;  end
                // D D E C | D E F E C | D E F E D | C D G-
                // (the original ends on a low G, below our range, so G4 is used)
                6'd30: idx = D;  6'd31: idx = D;  6'd32: idx = E;  6'd33: idx = C;
                6'd34: idx = D;
                6'd35: begin idx = E; len = N8; end
                6'd36: begin idx = F; len = N8; end
                6'd37: idx = E;  6'd38: idx = C;
                6'd39: idx = D;
                6'd40: begin idx = E; len = N8; end
                6'd41: begin idx = F; len = N8; end
                6'd42: idx = E;  6'd43: idx = D;
                6'd44: idx = C;  6'd45: idx = D;
                6'd46: begin idx = G; len = N2; end
                // E E F G | G F E D | C C D E | D. C C-
                6'd47: idx = E;  6'd48: idx = E;  6'd49: idx = F;  6'd50: idx = G;
                6'd51: idx = G;  6'd52: idx = F;  6'd53: idx = E;  6'd54: idx = D;
                6'd55: idx = C;  6'd56: idx = C;  6'd57: idx = D;  6'd58: idx = E;
                6'd59: begin idx = D; len = N4D; end
                6'd60: begin idx = C; len = N8;  end
                6'd61: begin idx = C; len = N2;  end
                default: idx = C;
            endcase
        end
    end

    // How long the current note sounds: len eighths minus the gap
    reg [25:0] note_cycles;
    always @(*) begin
        case (len)
            N8:      note_cycles = EIGHTH_CYCLES - GAP_CYCLES;
            N4:      note_cycles = EIGHTH_CYCLES + EIGHTH_CYCLES - GAP_CYCLES;
            N4D:     note_cycles = EIGHTH_CYCLES + EIGHTH_CYCLES + EIGHTH_CYCLES - GAP_CYCLES;
            default: note_cycles = EIGHTH_CYCLES + EIGHTH_CYCLES + EIGHTH_CYCLES
                                   + EIGHTH_CYCLES - GAP_CYCLES;          // N2
        endcase
    end

    // ---------------- sequencer ----------------
    always @(posedge clk) begin
        // Reset, demo off, or a different song chosen: go back to the start
        if (reset || !enable || song_sel != cur_sel) begin
            timer   <= 26'd0;
            step    <= 6'd0;
            gap     <= 1'b0;
            cur_sel <= song_sel;
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
            if (step == last_step)
                step <= 6'd0;
            else
                step <= step + 6'd1;
        end
        // Otherwise keep counting
        else begin
            timer <= timer + 26'd1;
        end
    end

    // Hold only the key for the current step; release all keys in the gap,
    // when off, or for the one cycle while a song change restarts the sequencer
    always @(*) begin
        key_down = 7'd0;                          // default (also prevents a latch)
        if (enable && !gap && song_sel == cur_sel)
            key_down[idx] = 1'b1;                 // e.g. idx = 4 -> 0010000 (Sol)
    end

endmodule
