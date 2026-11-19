// piano_renderer.v
// Combinational pixel colour for the piano screen (640x480).
// Given the current pixel (x, y) and the active note, returns its RGB.
//
// Screen layout
//   title "FPGA PIANO"       y  40..67   (5x7 font, 4x scale)
//   active-note bar          y 112..139  (above the pressed key, note colour)
//   7 white keys (Do..Si)    x 40..599, y 150..439, 80 px each
//   5 black keys (decor)     y 150..329, 46 px wide, on C|D D|E F|G G|A A|B
//   key labels DO RE MI ...  y 405..418  (5x7 font, 2x scale)
//
// The pressed white key is filled with a light tint of its note colour.

module piano_renderer (
    input      [9:0] x,
    input      [9:0] y,
    input      [2:0] active_note,   // 0 = none, 1..7 = Do..Si
    output reg [7:0] r,
    output reg [7:0] g,
    output reg [7:0] b
);

    // ---------------- geometry ----------------
    localparam KEYS_X0   = 10'd40;
    localparam KEY_W     = 10'd80;
    localparam KEYS_X1   = 10'd600;   // KEYS_X0 + 7*KEY_W
    localparam KEYS_Y0   = 10'd150;
    localparam KEYS_Y1   = 10'd440;
    localparam BLACK_Y1  = 10'd330;
    localparam BLACK_HW  = 10'd23;    // half width of a black key
    localparam BAR_Y0    = 10'd112;
    localparam BAR_Y1    = 10'd140;
    localparam LABEL_Y0  = 10'd405;
    localparam TITLE_X0  = 10'd160;
    localparam TITLE_Y0  = 10'd40;

    // ---------------- 5x7 font ----------------
    // char codes: 0 space, 1 D, 2 O, 3 R, 4 E, 5 M, 6 I, 7 F, 8 A,
    //             9 S, 10 L, 11 P, 12 G, 13 N
    function [4:0] font_row;
        input [3:0] code;
        input [2:0] row;
        begin
            case ({code, row})
            {4'd1, 3'd0}: font_row = 5'b11110;  // D
            {4'd1, 3'd1}: font_row = 5'b10001;  // D
            {4'd1, 3'd2}: font_row = 5'b10001;  // D
            {4'd1, 3'd3}: font_row = 5'b10001;  // D
            {4'd1, 3'd4}: font_row = 5'b10001;  // D
            {4'd1, 3'd5}: font_row = 5'b10001;  // D
            {4'd1, 3'd6}: font_row = 5'b11110;  // D
            {4'd2, 3'd0}: font_row = 5'b01110;  // O
            {4'd2, 3'd1}: font_row = 5'b10001;  // O
            {4'd2, 3'd2}: font_row = 5'b10001;  // O
            {4'd2, 3'd3}: font_row = 5'b10001;  // O
            {4'd2, 3'd4}: font_row = 5'b10001;  // O
            {4'd2, 3'd5}: font_row = 5'b10001;  // O
            {4'd2, 3'd6}: font_row = 5'b01110;  // O
            {4'd3, 3'd0}: font_row = 5'b11110;  // R
            {4'd3, 3'd1}: font_row = 5'b10001;  // R
            {4'd3, 3'd2}: font_row = 5'b10001;  // R
            {4'd3, 3'd3}: font_row = 5'b11110;  // R
            {4'd3, 3'd4}: font_row = 5'b10100;  // R
            {4'd3, 3'd5}: font_row = 5'b10010;  // R
            {4'd3, 3'd6}: font_row = 5'b10001;  // R
            {4'd4, 3'd0}: font_row = 5'b11111;  // E
            {4'd4, 3'd1}: font_row = 5'b10000;  // E
            {4'd4, 3'd2}: font_row = 5'b10000;  // E
            {4'd4, 3'd3}: font_row = 5'b11110;  // E
            {4'd4, 3'd4}: font_row = 5'b10000;  // E
            {4'd4, 3'd5}: font_row = 5'b10000;  // E
            {4'd4, 3'd6}: font_row = 5'b11111;  // E
            {4'd5, 3'd0}: font_row = 5'b10001;  // M
            {4'd5, 3'd1}: font_row = 5'b11011;  // M
            {4'd5, 3'd2}: font_row = 5'b10101;  // M
            {4'd5, 3'd3}: font_row = 5'b10101;  // M
            {4'd5, 3'd4}: font_row = 5'b10001;  // M
            {4'd5, 3'd5}: font_row = 5'b10001;  // M
            {4'd5, 3'd6}: font_row = 5'b10001;  // M
            {4'd6, 3'd0}: font_row = 5'b01110;  // I
            {4'd6, 3'd1}: font_row = 5'b00100;  // I
            {4'd6, 3'd2}: font_row = 5'b00100;  // I
            {4'd6, 3'd3}: font_row = 5'b00100;  // I
            {4'd6, 3'd4}: font_row = 5'b00100;  // I
            {4'd6, 3'd5}: font_row = 5'b00100;  // I
            {4'd6, 3'd6}: font_row = 5'b01110;  // I
            {4'd7, 3'd0}: font_row = 5'b11111;  // F
            {4'd7, 3'd1}: font_row = 5'b10000;  // F
            {4'd7, 3'd2}: font_row = 5'b10000;  // F
            {4'd7, 3'd3}: font_row = 5'b11110;  // F
            {4'd7, 3'd4}: font_row = 5'b10000;  // F
            {4'd7, 3'd5}: font_row = 5'b10000;  // F
            {4'd7, 3'd6}: font_row = 5'b10000;  // F
            {4'd8, 3'd0}: font_row = 5'b01110;  // A
            {4'd8, 3'd1}: font_row = 5'b10001;  // A
            {4'd8, 3'd2}: font_row = 5'b10001;  // A
            {4'd8, 3'd3}: font_row = 5'b11111;  // A
            {4'd8, 3'd4}: font_row = 5'b10001;  // A
            {4'd8, 3'd5}: font_row = 5'b10001;  // A
            {4'd8, 3'd6}: font_row = 5'b10001;  // A
            {4'd9, 3'd0}: font_row = 5'b01111;  // S
            {4'd9, 3'd1}: font_row = 5'b10000;  // S
            {4'd9, 3'd2}: font_row = 5'b10000;  // S
            {4'd9, 3'd3}: font_row = 5'b01110;  // S
            {4'd9, 3'd4}: font_row = 5'b00001;  // S
            {4'd9, 3'd5}: font_row = 5'b00001;  // S
            {4'd9, 3'd6}: font_row = 5'b11110;  // S
            {4'd10, 3'd0}: font_row = 5'b10000;  // L
            {4'd10, 3'd1}: font_row = 5'b10000;  // L
            {4'd10, 3'd2}: font_row = 5'b10000;  // L
            {4'd10, 3'd3}: font_row = 5'b10000;  // L
            {4'd10, 3'd4}: font_row = 5'b10000;  // L
            {4'd10, 3'd5}: font_row = 5'b10000;  // L
            {4'd10, 3'd6}: font_row = 5'b11111;  // L
            {4'd11, 3'd0}: font_row = 5'b11110;  // P
            {4'd11, 3'd1}: font_row = 5'b10001;  // P
            {4'd11, 3'd2}: font_row = 5'b10001;  // P
            {4'd11, 3'd3}: font_row = 5'b11110;  // P
            {4'd11, 3'd4}: font_row = 5'b10000;  // P
            {4'd11, 3'd5}: font_row = 5'b10000;  // P
            {4'd11, 3'd6}: font_row = 5'b10000;  // P
            {4'd12, 3'd0}: font_row = 5'b01110;  // G
            {4'd12, 3'd1}: font_row = 5'b10001;  // G
            {4'd12, 3'd2}: font_row = 5'b10000;  // G
            {4'd12, 3'd3}: font_row = 5'b10111;  // G
            {4'd12, 3'd4}: font_row = 5'b10001;  // G
            {4'd12, 3'd5}: font_row = 5'b10001;  // G
            {4'd12, 3'd6}: font_row = 5'b01111;  // G
            {4'd13, 3'd0}: font_row = 5'b10001;  // N
            {4'd13, 3'd1}: font_row = 5'b11001;  // N
            {4'd13, 3'd2}: font_row = 5'b10101;  // N
            {4'd13, 3'd3}: font_row = 5'b10011;  // N
            {4'd13, 3'd4}: font_row = 5'b10001;  // N
            {4'd13, 3'd5}: font_row = 5'b10001;  // N
            {4'd13, 3'd6}: font_row = 5'b10001;  // N                default: font_row = 5'b00000;
            endcase
        end
    endfunction

    // label text for white key k (0..6), character position i (0..2)
    function [3:0] label_char;
        input [2:0] k;
        input [1:0] i;
        begin
            label_char = 4'd0;
            case (k)
                3'd0: begin if (i == 2'd0) label_char = 4'd1;  if (i == 2'd1) label_char = 4'd2;  end // DO
                3'd1: begin if (i == 2'd0) label_char = 4'd3;  if (i == 2'd1) label_char = 4'd4;  end // RE
                3'd2: begin if (i == 2'd0) label_char = 4'd5;  if (i == 2'd1) label_char = 4'd6;  end // MI
                3'd3: begin if (i == 2'd0) label_char = 4'd7;  if (i == 2'd1) label_char = 4'd8;  end // FA
                3'd4: begin if (i == 2'd0) label_char = 4'd9;  if (i == 2'd1) label_char = 4'd2;
                            if (i == 2'd2) label_char = 4'd10; end                                    // SOL
                3'd5: begin if (i == 2'd0) label_char = 4'd10; if (i == 2'd1) label_char = 4'd8;  end // LA
                3'd6: begin if (i == 2'd0) label_char = 4'd9;  if (i == 2'd1) label_char = 4'd6;  end // SI
                default: label_char = 4'd0;
            endcase
        end
    endfunction

    // "FPGA PIANO"
    function [3:0] title_char;
        input [3:0] i;
        begin
            case (i)
                4'd0: title_char = 4'd7;   // F
                4'd1: title_char = 4'd11;  // P
                4'd2: title_char = 4'd12;  // G
                4'd3: title_char = 4'd8;   // A
                4'd4: title_char = 4'd0;   // space
                4'd5: title_char = 4'd11;  // P
                4'd6: title_char = 4'd6;   // I
                4'd7: title_char = 4'd8;   // A
                4'd8: title_char = 4'd13;  // N
                4'd9: title_char = 4'd2;   // O
                default: title_char = 4'd0;
            endcase
        end
    endfunction

    // note colour (rainbow): Do red ... Si violet
    function [23:0] note_color;
        input [2:0] n;
        begin
            case (n)
                3'd1:    note_color = 24'hFF3B3B;  // Do  - red
                3'd2:    note_color = 24'hFF9A1F;  // Re  - orange
                3'd3:    note_color = 24'hFFE01F;  // Mi  - yellow
                3'd4:    note_color = 24'h3DDC5A;  // Fa  - green
                3'd5:    note_color = 24'h22C7E8;  // Sol - cyan
                3'd6:    note_color = 24'h3B6BFF;  // La  - blue
                3'd7:    note_color = 24'hB04BFF;  // Si  - violet
                default: note_color = 24'hFFFFFF;
            endcase
        end
    endfunction

    // ---------------- per-pixel decode ----------------
    reg  [2:0]  key_idx;       // which white key column (0..6)
    reg  [9:0]  key_rel;       // x offset inside that white key (0..79)
    reg         in_keys;
    reg         in_black;
    reg  [23:0] ncol;          // active note colour
    reg  [23:0] tint;          // light version of ncol
    reg  [9:0]  lx;            // label-relative x
    reg  [9:0]  loff;          // label left offset inside the key
    reg  [9:0]  lwidth;
    reg  [9:0]  ty;            // title/label-relative y
    reg  [9:0]  tx;
    reg  [4:0]  frow;
    reg  [2:0]  fcol;
    reg         text_px;

    always @(*) begin
        // ---- defaults: background ----
        r = 8'd18; g = 8'd22; b = 8'd38;

        ncol = note_color(active_note);
        tint = {1'b1, ncol[23:17], 1'b1, ncol[15:9], 1'b1, ncol[7:1]}; // (c/2)+128

        // ---- which white key column ----
        in_keys = (x >= KEYS_X0) && (x < KEYS_X1) && (y >= KEYS_Y0) && (y < KEYS_Y1);
        key_idx = 3'd0;
        key_rel = 10'd0;
        if      (x < KEYS_X0 + 10'd80)  begin key_idx = 3'd0; key_rel = x - KEYS_X0;           end
        else if (x < KEYS_X0 + 10'd160) begin key_idx = 3'd1; key_rel = x - (KEYS_X0 + 10'd80);  end
        else if (x < KEYS_X0 + 10'd240) begin key_idx = 3'd2; key_rel = x - (KEYS_X0 + 10'd160); end
        else if (x < KEYS_X0 + 10'd320) begin key_idx = 3'd3; key_rel = x - (KEYS_X0 + 10'd240); end
        else if (x < KEYS_X0 + 10'd400) begin key_idx = 3'd4; key_rel = x - (KEYS_X0 + 10'd320); end
        else if (x < KEYS_X0 + 10'd480) begin key_idx = 3'd5; key_rel = x - (KEYS_X0 + 10'd400); end
        else                            begin key_idx = 3'd6; key_rel = x - (KEYS_X0 + 10'd480); end

        // ---- black keys sit on boundaries 1,2,4,5,6 (no black key between Mi|Fa) ----
        in_black = 1'b0;
        if (y >= KEYS_Y0 && y < BLACK_Y1) begin
            if ((key_idx == 3'd1 || key_idx == 3'd2 || key_idx == 3'd4 ||
                 key_idx == 3'd5 || key_idx == 3'd6) && key_rel < BLACK_HW)
                in_black = 1'b1;                          // left half sits on this key
            if ((key_idx == 3'd0 || key_idx == 3'd1 || key_idx == 3'd3 ||
                 key_idx == 3'd4 || key_idx == 3'd5) && key_rel >= KEY_W - BLACK_HW)
                in_black = 1'b1;                          // right half sits on this key
        end

        // ---- label text on white keys ----
        text_px = 1'b0;
        if (key_idx == 3'd4) begin loff = 10'd19; lwidth = 10'd48; end  // 3 chars
        else                 begin loff = 10'd27; lwidth = 10'd32; end  // 2 chars
        lx = key_rel - loff;
        ty = y - LABEL_Y0;
        frow = 5'd0;
        fcol = 3'd0;
        if (y >= LABEL_Y0 && y < LABEL_Y0 + 10'd14 && key_rel >= loff && key_rel < loff + lwidth) begin
            fcol = lx[3:1];                                       // 2x scale, 8-px cell
            frow = font_row(label_char(key_idx, lx[5:4]), ty[3:1]);
            if (fcol < 3'd5)
                text_px = frow[3'd4 - fcol];
        end

        // ---- draw keyboard ----
        if (in_keys) begin
            if (in_black) begin
                r = 8'd28; g = 8'd28; b = 8'd34;
                if (y >= BLACK_Y1 - 10'd6) begin                 // little bevel
                    r = 8'd70; g = 8'd70; b = 8'd80;
                end
            end
            else if (key_rel < 10'd2 || key_rel >= KEY_W - 10'd1 || y >= KEYS_Y1 - 10'd3) begin
                r = 8'd50; g = 8'd50; b = 8'd60;                  // key outline
            end
            else if (text_px) begin
                r = 8'd60; g = 8'd60; b = 8'd75;
            end
            else if (active_note != 3'd0 && key_idx == active_note - 3'd1) begin
                r = tint[23:16]; g = tint[15:8]; b = tint[7:0];  // pressed key
            end
            else begin
                r = 8'd245; g = 8'd243; b = 8'd235;              // ivory
            end
        end

        // ---- active-note bar above the pressed key ----
        if (active_note != 3'd0 && y >= BAR_Y0 && y < BAR_Y1 &&
            x >= KEYS_X0 && x < KEYS_X1 &&
            key_idx == active_note - 3'd1 && key_rel >= 10'd8 && key_rel < 10'd72) begin
            r = ncol[23:16]; g = ncol[15:8]; b = ncol[7:0];
        end

        // ---- title "FPGA PIANO" (4x scale, 32-px cells) ----
        tx = x - TITLE_X0;
        ty = y - TITLE_Y0;
        if (x >= TITLE_X0 && x < TITLE_X0 + 10'd320 && y >= TITLE_Y0 && y < TITLE_Y0 + 10'd28) begin
            fcol = tx[4:2];
            frow = font_row(title_char(tx[8:5]), ty[4:2]);
            if (fcol < 3'd5 && frow[3'd4 - fcol]) begin
                r = 8'd235; g = 8'd235; b = 8'd245;
            end
        end
    end

endmodule
