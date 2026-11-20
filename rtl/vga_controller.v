// vga_controller.v
// 640x480 @ 60 Hz VGA timing for the DE1-SoC. The screen is drawn pixel by
// pixel, left to right, top to bottom. This module tracks the current pixel
// (x, y), asks the renderer for its colour (r_in, g_in, b_in), and drives the
// sync/colour pins. Pixel clock = 25 MHz (CLOCK_50 divided by 2).
//
//   Horizontal: 640 visible | 16 front porch | 96 sync | 48 back porch = 800
//   Vertical  : 480 visible | 10 front porch |  2 sync | 33 back porch = 525
// (Porches/sync are the off-screen time the monitor needs between lines/frames.)

module vga_controller (
    input            clk,        // CLOCK_50
    input            reset,      // active-high, synchronous
    input      [7:0] r_in,
    input      [7:0] g_in,
    input      [7:0] b_in,
    output     [9:0] x,          // current pixel column (0..799)
    output     [9:0] y,          // current pixel row    (0..524)
    output reg       frame_start, // 1-cycle pulse at the top of each frame
    output reg [7:0] VGA_R,
    output reg [7:0] VGA_G,
    output reg [7:0] VGA_B,
    output reg       VGA_HS,
    output reg       VGA_VS,
    output reg       VGA_BLANK_N,
    output           VGA_SYNC_N,
    output           VGA_CLK
);

    localparam H_VISIBLE = 10'd640;
    localparam H_FP      = 10'd16;
    localparam H_SYNC    = 10'd96;
    localparam H_TOTAL   = 10'd800;
    localparam V_VISIBLE = 10'd480;
    localparam V_FP      = 10'd10;
    localparam V_SYNC    = 10'd2;
    localparam V_TOTAL   = 10'd525;

    // 25 MHz pixel clock: pclk toggles every 50 MHz cycle. Logic updates when
    // pclk is about to fall, so data is stable 20 ns before VGA_CLK rises.
    reg pclk;
    wire pix_en = pclk;       // 1 every other 50 MHz cycle = once per pixel

    reg [9:0] hcount;         // current column (0..799)
    reg [9:0] vcount;         // current row    (0..524)

    assign x = hcount;
    assign y = vcount;
    assign VGA_CLK    = pclk;
    assign VGA_SYNC_N = 1'b0;   // sync-on-green not used

    always @(posedge clk) begin
        if (reset)
            pclk <= 1'b0;
        else
            pclk <= ~pclk;
    end

    // Pixel counters: step x every pixel; at the end of a line, go to the next
    // row; at the end of the last row, go back to the top of the screen.
    always @(posedge clk) begin
        if (reset) begin
            hcount <= 10'd0;
            vcount <= 10'd0;
        end
        else if (pix_en) begin
            if (hcount == H_TOTAL - 10'd1) begin
                hcount <= 10'd0;
                if (vcount == V_TOTAL - 10'd1)
                    vcount <= 10'd0;
                else
                    vcount <= vcount + 10'd1;
            end
            else begin
                hcount <= hcount + 10'd1;
            end
        end
    end

    // For the current pixel: are we in a sync pulse, and is it on screen
    reg hs_now, vs_now, visible_now;
    always @(*) begin
        hs_now = 1'b1;
        if (hcount >= H_VISIBLE + H_FP && hcount < H_VISIBLE + H_FP + H_SYNC)
            hs_now = 1'b0;             // active-low

        vs_now = 1'b1;
        if (vcount >= V_VISIBLE + V_FP && vcount < V_VISIBLE + V_FP + V_SYNC)
            vs_now = 1'b0;             // active-low

        visible_now = 1'b0;
        if (hcount < H_VISIBLE && vcount < V_VISIBLE)
            visible_now = 1'b1;
    end

    // Output registers: sync, blank and colour are all registered together,
    // so they stay aligned to the same pixel. Colour is forced to black
    // off-screen, as the VGA standard requires.
    always @(posedge clk) begin
        if (reset) begin
            VGA_HS      <= 1'b1;
            VGA_VS      <= 1'b1;
            VGA_BLANK_N <= 1'b0;
            VGA_R       <= 8'd0;
            VGA_G       <= 8'd0;
            VGA_B       <= 8'd0;
            frame_start <= 1'b0;
        end
        else begin
            frame_start <= 1'b0;
            if (pix_en) begin
                VGA_HS      <= hs_now;
                VGA_VS      <= vs_now;
                VGA_BLANK_N <= visible_now;
                if (visible_now) begin
                    VGA_R <= r_in;
                    VGA_G <= g_in;
                    VGA_B <= b_in;
                end
                else begin
                    VGA_R <= 8'd0;
                    VGA_G <= 8'd0;
                    VGA_B <= 8'd0;
                end
                if (hcount == 10'd0 && vcount == 10'd0)
                    frame_start <= 1'b1;
            end
        end
    end

endmodule
