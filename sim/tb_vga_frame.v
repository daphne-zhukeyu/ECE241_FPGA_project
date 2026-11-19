`timescale 1ns/1ps
// Simulates vga_controller + piano_renderer, checks 640x480@60 timing,
// and dumps the visible frame to frame.ppm (as the monitor would see it).
module tb_vga_frame;
    reg clk = 0, reset = 1;
    reg [2:0] active_note;
    wire [9:0] x, y;
    wire [7:0] r, g, b, R, G, B;
    wire hs, vs, blank_n, sync_n, vclk, fs;
    integer errors = 0;

    piano_renderer ren (.x(x), .y(y), .active_note(active_note), .r(r), .g(g), .b(b));
    vga_controller vga (.clk(clk), .reset(reset), .r_in(r), .g_in(g), .b_in(b), .x(x), .y(y),
        .frame_start(fs), .VGA_R(R), .VGA_G(G), .VGA_B(B), .VGA_HS(hs), .VGA_VS(vs),
        .VGA_BLANK_N(blank_n), .VGA_SYNC_N(sync_n), .VGA_CLK(vclk));
    always #10 clk = ~clk;

    // count pixel clocks per line / lines per frame from the sync outputs
    integer pix = 0, hs_low = 0, vis_in_line = 0, lines = 0, vis_lines = 0, line_len = 0;
    integer fd, px_count, frame_no = 0;
    reg capture = 0;
    reg hs_d = 1, vs_d = 1;
    always @(posedge vclk) begin
        pix = pix + 1;
        if (!hs) hs_low = hs_low + 1;
        if (blank_n) vis_in_line = vis_in_line + 1;
        if (capture && blank_n) begin
            $fwrite(fd, "%c%c%c", R, G, B);
            px_count = px_count + 1;
        end
        if (hs_d && !hs) begin                   // start of h-sync = end of line
            if (lines > 2) begin
                if (line_len != 0 && pix != 800) begin $display("FAIL line length %0d", pix); errors = errors + 1; end
                if (hs_low != 96 && lines > 3) ; // measured next edge
            end
            if (vis_in_line != 0) vis_lines = vis_lines + 1;
            if (vis_in_line != 0 && vis_in_line != 640) begin $display("FAIL visible px %0d", vis_in_line); errors = errors + 1; end
            line_len = pix; pix = 0; vis_in_line = 0; lines = lines + 1;
        end
        if (!hs_d && hs) begin
            if (hs_low != 96) begin $display("FAIL hsync width %0d", hs_low); errors = errors + 1; end
            hs_low = 0;
        end
        hs_d = hs;
    end

    integer vs_lines;
    initial begin
        if (!$value$plusargs("note=%d", active_note)) active_note = 3;
        repeat(4) @(posedge clk); reset = 0;
        // wait for first vsync, then measure a full frame
        @(negedge vs); lines = 0; vis_lines = 0;
        @(negedge vs);
        $display("lines per frame = %0d, visible lines = %0d", lines, vis_lines);
        if (lines != 525) begin $display("FAIL lines/frame"); errors = errors + 1; end
        if (vis_lines != 480) begin $display("FAIL visible lines"); errors = errors + 1; end
        // capture next frame
        @(posedge fs);
        fd = $fopen("frame.ppm", "wb"); $fwrite(fd, "P6\n640 480\n255\n");
        px_count = 0; capture = 1;
        @(negedge vs); capture = 0; $fclose(fd);
        $display("captured %0d pixels", px_count);
        if (px_count != 640*480) begin $display("FAIL capture size"); errors = errors + 1; end
        if (errors == 0) $display("PASS vga timing (800x525, hsync 96, 640x480 visible)");
        else $display("FAILED %0d", errors);
        $finish;
    end
endmodule
