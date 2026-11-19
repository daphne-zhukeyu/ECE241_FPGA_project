// tone_generator.v
// Square-wave tone for the 7 basic notes (C4..B4), clocked at 50 MHz.
// half_period = CLOCK_50 / (2 * f)
//
//   note  name  freq (Hz)  half_period
//    1    Do    261.63     95555
//    2    Re    293.66     85132
//    3    Mi    329.63     75843
//    4    Fa    349.23     71586
//    5    Sol   392.00     63776
//    6    La    440.00     56818
//    7    Si    493.88     50620
//
// sample is a signed 32-bit value for Audio_Controller (left-justified data).

module tone_generator #(
    parameter [31:0] AMPLITUDE = 32'd10000000
)(
    input             clk,          // CLOCK_50
    input             reset,        // active-high, synchronous
    input      [2:0]  note,         // 0 = silent, 1..7 = Do..Si
    output reg [31:0] sample
);

    reg [16:0] half_period;
    reg [16:0] count;
    reg        phase;
    reg [2:0]  prev_note;

    // note -> half period lookup
    always @(*) begin
        case (note)
            3'd1:    half_period = 17'd95555;
            3'd2:    half_period = 17'd85132;
            3'd3:    half_period = 17'd75843;
            3'd4:    half_period = 17'd71586;
            3'd5:    half_period = 17'd63776;
            3'd6:    half_period = 17'd56818;
            3'd7:    half_period = 17'd50620;
            default: half_period = 17'd0;
        endcase
    end

    // divider: toggle phase every half_period clocks
    always @(posedge clk) begin
        if (reset) begin
            count     <= 17'd0;
            phase     <= 1'b0;
            prev_note <= 3'd0;
        end
        else begin
            prev_note <= note;
            if (note == 3'd0 || note != prev_note) begin
                // silent or note just changed: restart cleanly
                count <= 17'd0;
                phase <= 1'b0;
            end
            else if (count == half_period - 17'd1) begin
                count <= 17'd0;
                phase <= ~phase;
            end
            else begin
                count <= count + 17'd1;
            end
        end
    end

    // output sample
    always @(*) begin
        if (note == 3'd0)
            sample = 32'd0;
        else if (phase)
            sample = AMPLITUDE;
        else
            sample = 32'd0 - AMPLITUDE;
    end

endmodule
