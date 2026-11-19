`timescale 1ns/1ps
module tb_tone_generator;
    reg clk = 0, reset = 1;
    reg [2:0] note = 0;
    wire [31:0] sample;
    integer errors = 0, n, t_last, t_now, half, k;
    integer expect_half [1:7];
    tone_generator dut (.clk(clk), .reset(reset), .note(note), .sample(sample));
    always #10 clk = ~clk;   // 50 MHz
    integer cyc = 0;
    always @(posedge clk) cyc = cyc + 1;

    initial begin
        expect_half[1]=95555; expect_half[2]=85132; expect_half[3]=75843; expect_half[4]=71586;
        expect_half[5]=63776; expect_half[6]=56818; expect_half[7]=50620;
        repeat(3) @(posedge clk); reset = 0;
        @(posedge clk); #1;
        if (sample !== 0) begin $display("FAIL silent sample=%0d", sample); errors=errors+1; end
        for (n = 1; n <= 7; n = n + 1) begin
            note = n;
            @(sample); @(sample); t_last = cyc;   // skip start-up edge after note change
            for (k = 0; k < 3; k = k + 1) begin
                @(sample); t_now = cyc;
                half = t_now - t_last; t_last = t_now;
                if (half != expect_half[n]) begin
                    $display("FAIL note %0d half=%0d expected %0d", n, half, expect_half[n]); errors=errors+1;
                end
            end
            $display("note %0d half-period %0d cycles -> %0.2f Hz", n, half, 50.0e6/(2.0*half));
        end
        note = 0; @(posedge clk); #1;
        if (sample !== 0) begin $display("FAIL not silent after note off"); errors=errors+1; end
        if (errors == 0) $display("PASS tone_generator"); else $display("FAILED %0d", errors);
        $finish;
    end
endmodule
