// piano_top.v  --  FPGA Digital Piano, Milestone 1 top level (DE1-SoC)
//
// Controls (Milestone 1, before PS/2 keyboard input exists):
//   KEY[0]   : reset (press = reset)
//   SW[6:0]  : hold a note  (SW0 = Do ... SW6 = Si)
//   SW[9]    : demo: plays "Twinkle Twinkle Little Star" (ignores SW[6:0])
//   SW[8]    : demo: plays "Ode to Joy"                  (ignores SW[6:0])
//   SW8 + SW9: error -> silent, "Err" on HEX2..HEX0
//   LEDR[6:0]: which keys are held,  LEDR[9:7]: active note number
//   HEX0     : active note letter (C d E F G A b), '-' when silent
//
// Data flow: switches/demo -> key_down -> note_control -> active_note
//            -> tone_generator (audio), piano_renderer (VGA), LEDR/HEX0.
// Milestone 2: replace `sw_keys` with key_down[6:0] from the PS/2 decoder.

module piano_top (
    input         CLOCK_50,
    input  [3:0]  KEY,
    input  [9:0]  SW,
    output [9:0]  LEDR,
    output reg [6:0] HEX0,
    output reg [6:0] HEX1,
    output reg [6:0] HEX2,

    // audio codec (WM8731) and its I2C configuration bus
    input         AUD_ADCDAT,
    inout         AUD_BCLK,
    inout         AUD_ADCLRCK,
    inout         AUD_DACLRCK,
    inout         FPGA_I2C_SDAT,
    output        AUD_XCK,
    output        AUD_DACDAT,
    output        FPGA_I2C_SCLK,

    // VGA DAC
    output [7:0]  VGA_R,
    output [7:0]  VGA_G,
    output [7:0]  VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_BLANK_N,
    output        VGA_SYNC_N,
    output        VGA_CLK
);

    wire reset = ~KEY[0];          // KEY0 is active-low: pressed = reset

    // ---------------- note events ----------------
    // 2-stage synchronizer: switches change at random times, so pass them
    // through two registers before use to avoid metastability (2-cycle delay)
    reg [9:0] sw_meta, sw_sync;
    always @(posedge CLOCK_50) begin
        sw_meta <= SW;
        sw_sync <= sw_meta;
    end

    wire [6:0] sw_keys = sw_sync[6:0];   // manual keys from SW0..SW6
    wire [6:0] demo_keys;                // automatic keys from demo_player

    // Mode from SW8/SW9: exactly one on -> play that song, both on -> error
    wire err     = sw_sync[8] & sw_sync[9];
    wire demo_on = sw_sync[8] ^ sw_sync[9];

    // Demo: SW9 -> Twinkle Twinkle (song 0), SW8 -> Ode to Joy (song 1)
    demo_player demo (
        .clk      (CLOCK_50),
        .reset    (reset),
        .enable   (demo_on),
        .song_sel (sw_sync[8]),
        .key_down (demo_keys)
    );

    // Select key source: error -> no keys (silent), demo -> song, else switches
    reg [6:0] key_down;
    always @(*) begin
        if (err)
            key_down = 7'd0;
        else if (demo_on)
            key_down = demo_keys;
        else
            key_down = sw_keys;
    end

    // Resolve the held keys into one note (0 = silent, 1..7 = Do..Si)
    wire [2:0] active_note;

    note_control nc (
        .clk         (CLOCK_50),
        .reset       (reset),
        .key_down    (key_down),
        .active_note (active_note)
    );

    // ---------------- audio ----------------
    // Note -> square-wave audio sample
    wire [31:0] sample;

    tone_generator tg (
        .clk    (CLOCK_50),
        .reset  (reset),
        .note   (active_note),
        .sample (sample)
    );

    wire        audio_in_available;
    wire [31:0] left_channel_audio_in;
    wire [31:0] right_channel_audio_in;
    wire        audio_out_allowed;

    // Course audio IP: sends samples to the codec at 48 kHz. We write the same
    // sample to both channels whenever its output buffer has room.
    Audio_Controller Audio_Controller (
        .CLOCK_50                (CLOCK_50),
        .reset                   (reset),
        .clear_audio_in_memory   (1'b0),
        .read_audio_in           (audio_in_available),   // just drain the ADC FIFO
        .clear_audio_out_memory  (1'b0),
        .left_channel_audio_out  (sample),
        .right_channel_audio_out (sample),
        .write_audio_out         (audio_out_allowed),
        .AUD_ADCDAT              (AUD_ADCDAT),
        .AUD_BCLK                (AUD_BCLK),
        .AUD_ADCLRCK             (AUD_ADCLRCK),
        .AUD_DACLRCK             (AUD_DACLRCK),
        .audio_in_available      (audio_in_available),
        .left_channel_audio_in   (left_channel_audio_in),
        .right_channel_audio_in  (right_channel_audio_in),
        .audio_out_allowed       (audio_out_allowed),
        .AUD_XCK                 (AUD_XCK),
        .AUD_DACDAT              (AUD_DACDAT)
    );

    // Course IP: configures the codec over I2C at power-up (microphone off)
    avconf #(.USE_MIC_INPUT(0)) avc (
        .FPGA_I2C_SCLK (FPGA_I2C_SCLK),
        .FPGA_I2C_SDAT (FPGA_I2C_SDAT),
        .CLOCK_50      (CLOCK_50),
        .reset         (reset)
    );

    // ---------------- VGA ----------------
    wire [9:0] px, py;
    wire [7:0] pr, pg, pb;
    wire       frame_start;            // unused for now

    // Renderer gives the colour of pixel (px, py); vga_controller scans the
    // screen and drives the VGA pins
    piano_renderer render (
        .x           (px),
        .y           (py),
        .active_note (active_note),
        .r           (pr),
        .g           (pg),
        .b           (pb)
    );

    vga_controller vga (
        .clk         (CLOCK_50),
        .reset       (reset),
        .r_in        (pr),
        .g_in        (pg),
        .b_in        (pb),
        .x           (px),
        .y           (py),
        .frame_start (frame_start),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),
        .VGA_CLK     (VGA_CLK)
    );

    // ---------------- debug outputs ----------------
    // Let us check the logic even without a monitor or speaker
    assign LEDR[6:0] = key_down;       // keys held
    assign LEDR[9:7] = active_note;    // note number in binary

    // HEX0 shows the note letter (segments are active-low, order {g,f,e,d,c,b,a})
    always @(*) begin
        case (active_note)
            3'd1:    HEX0 = 7'b1000110;  // C
            3'd2:    HEX0 = 7'b0100001;  // d
            3'd3:    HEX0 = 7'b0000110;  // E
            3'd4:    HEX0 = 7'b0001110;  // F
            3'd5:    HEX0 = 7'b1000010;  // G
            3'd6:    HEX0 = 7'b0001000;  // A
            3'd7:    HEX0 = 7'b0000011;  // b
            default: HEX0 = 7'b0111111;  // -
        endcase
        HEX1 = 7'b1111111;               // blank
        HEX2 = 7'b1111111;               // blank

        // SW8 and SW9 both on: show "Err" on HEX2 HEX1 HEX0
        if (err) begin
            HEX2 = 7'b0000110;           // E
            HEX1 = 7'b0101111;           // r
            HEX0 = 7'b0101111;           // r
        end
    end

endmodule
