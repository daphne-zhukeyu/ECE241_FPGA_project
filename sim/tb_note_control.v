`timescale 1ns/1ps
module tb_note_control;
    reg clk = 0, reset = 1;
    reg [6:0] key_down = 0;
    wire [2:0] active_note;
    integer errors = 0;
    note_control dut (.clk(clk), .reset(reset), .key_down(key_down), .active_note(active_note));
    always #10 clk = ~clk;

    task step(input [6:0] k, input [2:0] expect_note);
        begin
            key_down = k;
            @(posedge clk); @(posedge clk); #1;
            if (active_note !== expect_note) begin
                $display("FAIL keys=%b expected %0d got %0d", k, expect_note, active_note);
                errors = errors + 1;
            end else
                $display("ok   keys=%b -> note %0d", k, active_note);
        end
    endtask

    initial begin
        @(posedge clk); @(posedge clk); reset = 0;
        step(7'b0000000, 0);   // silent
        step(7'b0000001, 1);   // Do
        step(7'b0000000, 0);   // release
        step(7'b0000100, 3);   // Mi
        step(7'b0100100, 6);   // + La, newest wins
        step(7'b0000100, 3);   // release La -> back to Mi
        step(7'b1000100, 7);   // + Si
        step(7'b1000000, 7);   // release Mi, Si still active
        step(7'b0000000, 0);
        step(7'b0010000, 5);   // Sol
        reset = 1; @(posedge clk); #1;
        if (active_note !== 0) begin $display("FAIL reset"); errors = errors + 1; end
        if (errors == 0) $display("PASS note_control");
        else $display("FAILED %0d checks", errors);
        $finish;
    end
endmodule
