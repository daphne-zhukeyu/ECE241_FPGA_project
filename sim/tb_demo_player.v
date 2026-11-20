`timescale 1ns/1ps
// tb_demo_player.v
// Plays the Twinkle Twinkle demo with short timing (ON = 8, GAP = 2 cycles)
// and checks every note: correct key, correct length (short = 8, long = 18),
// a gap after each note, and that the song restarts after the last note.

module tb_demo_player;

    reg        clk    = 1'b0;
    reg        reset  = 1'b1;
    reg        enable = 1'b0;
    wire [6:0] key_down;

    demo_player #(.ON_CYCLES(26'd8), .GAP_CYCLES(26'd2)) dut (
        .clk      (clk),
        .reset    (reset),
        .enable   (enable),
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

    // Expected song: one-hot key and length for each of the 42 notes
    reg [6:0] exp_key [0:41];
    integer   exp_len [0:41];
    integer   i, n, len, errors;

    task set_line(input integer base,
                  input [6:0] k0, input [6:0] k1, input [6:0] k2, input [6:0] k3,
                  input [6:0] k4, input [6:0] k5, input [6:0] k6);
        begin
            exp_key[base]   = k0; exp_key[base+1] = k1; exp_key[base+2] = k2;
            exp_key[base+3] = k3; exp_key[base+4] = k4; exp_key[base+5] = k5;
            exp_key[base+6] = k6;
            for (i = 0; i < 6; i = i + 1) exp_len[base+i] = 8;
            exp_len[base+6] = 18;                         // last note of each line is long
        end
    endtask

    localparam [6:0] C = 7'b0000001, D = 7'b0000010, E = 7'b0000100, F = 7'b0001000,
                     G = 7'b0010000, A = 7'b0100000;

    initial begin
        errors = 0;
        set_line( 0, C, C, G, G, A, A, G);
        set_line( 7, F, F, E, E, D, D, C);
        set_line(14, G, G, F, F, E, E, D);
        set_line(21, G, G, F, F, E, E, D);
        set_line(28, C, C, G, G, A, A, G);
        set_line(35, F, F, E, E, D, D, C);

        repeat (3) @(posedge clk);
        reset = 1'b0;
        @(negedge clk);
        if (key_down !== 7'd0) begin $display("FAIL: keys on while disabled"); errors = errors + 1; end
        enable = 1'b1;

        // Check all 42 notes, then the first note of the repeat
        for (n = 0; n <= 42; n = n + 1) begin
            if (n > 0)
                @(negedge clk);                            // first cycle of the next note
            #1;
            if (key_down !== exp_key[n % 42]) begin
                $display("FAIL note %0d: key %b, expected %b", n, key_down, exp_key[n % 42]);
                errors = errors + 1;
            end
            len = 0;
            while (key_down !== 7'd0) begin
                len = len + 1;
                @(negedge clk);
            end
            if (n < 42 && len != exp_len[n]) begin
                $display("FAIL note %0d: length %0d, expected %0d", n, len, exp_len[n]);
                errors = errors + 1;
            end
            @(negedge clk);                                // second gap cycle
            if (key_down !== 7'd0 && n < 42) begin
                $display("FAIL note %0d: gap too short", n);
                errors = errors + 1;
            end
        end

        // Turning the demo off releases all keys
        enable = 1'b0;
        @(negedge clk);
        if (key_down !== 7'd0) begin $display("FAIL: keys on after disable"); errors = errors + 1; end

        if (errors == 0)
            $display("PASS demo_player: all 42 notes of Twinkle Twinkle correct, song restarts");
        else
            $display("FAILED demo_player: %0d errors", errors);
        $stop;
    end

endmodule
