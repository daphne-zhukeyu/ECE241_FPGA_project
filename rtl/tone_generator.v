// tone_generator.v
// Square-wave tone for the 7 notes. A counter flips the wave every
// half_period clock cycles, where half_period = 50 MHz / (2 x frequency).
//
//   note  name  freq (Hz)  half_period
//    1    Do    261.63     95555
//    2    Re    293.66     85132
//    3    Mi    329.63     75843
//    4    Fa    349.23     71586
//    5    Sol   392.00     63776
//    6    La    440.00     56818
//    7    Si    493.88     50620

module tone_generator #(
    parameter [31:0] AMPLITUDE = 32'd10000000   // wave height (sets volume)
)(
    input             clk,          // 50 MHz
    input             reset,        // active-high, synchronous
    input      [2:0]  note,         // 0 = silent, 1..7 = Do..Si
    output reg [31:0] sample        // audio value sent to Audio_Controller
);

    reg [16:0] half_period;   // cycles per half wave (17 bits: max 95555)
    reg [16:0] count;         // cycles since the last flip
    reg        phase;         // 1 = high half of the wave, 0 = low half
    reg [2:0]  prev_note;     // note from last cycle, to detect a change

    // Look up the half period for the current note
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

    // Counter: flip phase every half_period cycles
    always @(posedge clk) begin
        if (reset) begin
            count     <= 17'd0;
            phase     <= 1'b0;
            prev_note <= 3'd0;
        end
        else begin
            prev_note <= note;
            if (note == 3'd0 || note != prev_note) begin
                count <= 17'd0;            // silent or new note: restart the wave
                phase <= 1'b0;
            end
            else if (count == half_period - 17'd1) begin
                count <= 17'd0;            // half wave done: flip
                phase <= ~phase;
            end
            else begin
                count <= count + 17'd1;
            end
        end
    end

    // Output: 0 when silent, otherwise +AMPLITUDE / -AMPLITUDE
    always @(*) begin
        if (note == 3'd0)
            sample = 32'd0;
        else if (phase)
            sample = AMPLITUDE;
        else
            sample = 32'd0 - AMPLITUDE;    // two's complement negative
    end

endmodule
