`timescale 1ns/1ps
// tb_demo_player.v
// Plays both demo songs with short timing (EIGHTH = 5, GAP = 2 cycles) and
// checks every note: correct key, correct length, a gap after each note,
// and that each song restarts after its last note.
// Sound lengths with these settings: eighth = 3, quarter = 8,
// dotted quarter = 13, half = 18 cycles.

module tb_demo_player;

    reg        clk      = 1'b0;
    reg        reset    = 1'b1;
    reg        enable   = 1'b0;
    reg        song_sel = 1'b0;
    wire [6:0] key_down;

    demo_player #(.EIGHTH_CYCLES(26'd5), .GAP_CYCLES(26'd2)) dut (
        .clk      (clk),
        .reset    (reset),
        .enable   (enable),
        .song_sel (song_sel),
        .key_down (key_down)
    );

    always #10 clk = ~clk;

    // Named lines for the wave window
    wire Do  = key_down[0];
    wire Re  = key_down[1];
    wire Mi  = key_down[2];
    wire Fa  = key_down[3];
    wire Sol = key_down[4];
    wire La  = key_down[5];
    wire Si  = key_down[6];

    localparam [6:0] C = 7'b0000001, D = 7'b0000010, E = 7'b0000100, F = 7'b0001000,
                     G = 7'b0010000, A = 7'b0100000;
    localparam integer Q = 8, H = 18, E8 = 3, QD = 13;   // expected sound lengths

    // Expected notes for the song under test
    reg [6:0] exp_key [0:63];
    integer   exp_len [0:63];
    integer   num_notes, n, k, len, errors;

    // Add one note to the expected list
    task add(input [6:0] key, input integer l);
        begin
            exp_key[num_notes] = key;
            exp_len[num_notes] = l;
            num_notes = num_notes + 1;
        end
    endtask

    // Play the loaded song once (plus the first note of the repeat) and check it
    task check_song(input [8*12-1:0] name);
        begin
            for (n = 0; n <= num_notes; n = n + 1) begin
                if (n > 0)
                    @(negedge clk);                        // first cycle of the next note
                #1;
                k = n % num_notes;
                if (key_down !== exp_key[k]) begin
                    $display("FAIL %0s note %0d: key %b, expected %b", name, n, key_down, exp_key[k]);
                    errors = errors + 1;
                end
                len = 0;
                while (key_down !== 7'd0) begin
                    len = len + 1;
                    @(negedge clk);
                end
                if (n < num_notes && len != exp_len[k]) begin
                    $display("FAIL %0s note %0d: length %0d, expected %0d", name, n, len, exp_len[k]);
                    errors = errors + 1;
                end
                @(negedge clk);                            // second gap cycle
            end
            $display("%0s: checked %0d notes", name, num_notes);
        end
    endtask

    initial begin
        errors = 0;
        repeat (3) @(posedge clk);
        reset = 1'b0;
        @(negedge clk);
        if (key_down !== 7'd0) begin $display("FAIL: keys on while disabled"); errors = errors + 1; end

        // ---------------- Twinkle Twinkle (song 0) ----------------
        num_notes = 0;
        add(C,Q); add(C,Q); add(G,Q); add(G,Q); add(A,Q); add(A,Q); add(G,H);
        add(F,Q); add(F,Q); add(E,Q); add(E,Q); add(D,Q); add(D,Q); add(C,H);
        add(G,Q); add(G,Q); add(F,Q); add(F,Q); add(E,Q); add(E,Q); add(D,H);
        add(G,Q); add(G,Q); add(F,Q); add(F,Q); add(E,Q); add(E,Q); add(D,H);
        add(C,Q); add(C,Q); add(G,Q); add(G,Q); add(A,Q); add(A,Q); add(G,H);
        add(F,Q); add(F,Q); add(E,Q); add(E,Q); add(D,Q); add(D,Q); add(C,H);
        song_sel = 1'b0;
        enable   = 1'b1;
        check_song("Twinkle");

        // Turn off, then switch to Ode to Joy
        enable = 1'b0;
        @(negedge clk); #1;
        if (key_down !== 7'd0) begin $display("FAIL: keys on after disable"); errors = errors + 1; end

        // ---------------- Ode to Joy (song 1) ----------------
        num_notes = 0;
        add(E,Q); add(E,Q); add(F,Q); add(G,Q); add(G,Q); add(F,Q); add(E,Q); add(D,Q);
        add(C,Q); add(C,Q); add(D,Q); add(E,Q); add(E,QD); add(D,E8); add(D,H);
        add(E,Q); add(E,Q); add(F,Q); add(G,Q); add(G,Q); add(F,Q); add(E,Q); add(D,Q);
        add(C,Q); add(C,Q); add(D,Q); add(E,Q); add(D,QD); add(C,E8); add(C,H);
        add(D,Q); add(D,Q); add(E,Q); add(C,Q);
        add(D,Q); add(E,E8); add(F,E8); add(E,Q); add(C,Q);
        add(D,Q); add(E,E8); add(F,E8); add(E,Q); add(D,Q);
        add(C,Q); add(D,Q); add(G,H);
        add(E,Q); add(E,Q); add(F,Q); add(G,Q); add(G,Q); add(F,Q); add(E,Q); add(D,Q);
        add(C,Q); add(C,Q); add(D,Q); add(E,Q); add(D,QD); add(C,E8); add(C,H);
        song_sel = 1'b1;
        @(negedge clk);
        enable   = 1'b1;
        check_song("Ode to Joy");

        // Switching song while playing restarts from the new song's first note
        repeat (20) @(negedge clk);
        song_sel = 1'b0;
        @(negedge clk);                                    // restart cycle
        @(negedge clk); #1;
        if (key_down !== C) begin
            $display("FAIL: song switch did not restart Twinkle (key %b)", key_down);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS demo_player: Twinkle (42 notes) and Ode to Joy (62 notes) correct, both loop");
        else
            $display("FAILED demo_player: %0d errors", errors);
        $stop;
    end

endmodule
