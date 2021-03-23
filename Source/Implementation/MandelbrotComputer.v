module MandelbrotComputer
(
    input clock,
    input reset_n,

    input zoom_in,
    input zoom_out,

    input pan_up, 
    input pan_down,
    input pan_left,
    input pan_right,

    input [9:0] vga_row_in,
    input [9:0] vga_col_in,

    output [23:0] vram_out
);
    localparam DEFAULT_HEIGHT = 64'h3FF8000000000000;   /* 2.0 */
    localparam DEFAULT_WIDTH = 64'h4000000000000000;    /* 1.5 */
    localparam VGA_BLACK = 24'hFFFFFF;

    /* Head module - ResolutionTranslationCache                               */
    /* ---------------------------------------------------------------------- */
    /* Fans out results to four cell workers, each of which works on a quad.  */
    /* of the screen.                                                         */
    wire [3:0] rtc_read_req;
    wire [3:0] rtc_ready_for_read;

    wire [67:0] rtc_idx_out;
    wire [255:0] rtc_x0_out;
    wire [255:0] rtc_y0_out;

    wire [16:0] idx_fan[0:3];
    wire [63:0] x0_fan[0:3];
    wire [63:0] y0_fan[0:3];

    assign { x0_fan[3], x0_fan[2], x0_fan[1], x0_fan[0] } = rtc_x0_out;
    assign { y0_fan[3], y0_fan[2], y0_fan[1], y0_fan[0] } = rtc_y0_out;
    assign { idx_fan[3], idx_fan[2], idx_fan[1], idx_fan[0] } = rtc_idx_out; 

    /* View Controller for input centers and width / height                  */
    /*---------------------------------------------------------------------- */
    wire [63:0] width, height, x_center, y_center;

    ViewController view_controller
    (
        .clock(clock),
        .reset_n(reset_n),

        .pan_up(pan_up),
        .pan_down(pan_down),
        .pan_left(pan_left),
        .pan_right(pan_right),

        .zoom_in(zoom_in),
        .zoom_out(zoom_out),

        .x_center(x_center),
        .y_center(y_center),

        .width(width),
        .height(height)
    );

    ResolutionTranslationCache rtc
    (
        .clock(clock),
        .reset_n(reset_n),

        .x_center_in(x_center),
        .y_center_in(y_center),
        .width_in(width),
        .height_in(height),

        .read_req(rtc_read_req),
        .ready_for_read(rtc_ready_for_read),

        .idx_out(rtc_idx_out),
        .x0_out(rtc_x0_out),
        .y0_out(rtc_y0_out)
    );

    /* Final selector - partitions screen into four quads and determines what */
    /* quad and what index to use in that quad.                               */
    /* ---------------------------------------------------------------------- */

    wire [7:0] iter_from_workers[0:3];
    wire [1:0] quad_select;
    wire [16:0] vga_read_idx;
    wire vga_out_of_bounds;

    VGARowColToIndexConverter converter
    (
        .vga_row(vga_row_in),
        .vga_col(vga_col_in),

        .out_of_bounds(vga_out_of_bounds),
        .quad_select(quad_select),
        .idx_out(vga_read_idx)
    );

    assign vram_out = vga_out_of_bounds 
        ? VGA_BLACK : { 6{ iter_from_workers[quad_select][7:4] } };

    /* Cell Workers - one for each corner                                     */
    /* ---------------------------------------------------------------------- */
    generate
        genvar i;
        for (i = 0; i < 4; i = i + 1) begin: cell_worker_block
            CellWorker worker
            (
                .clock(clock),
                .reset_n(reset_n),

                .iter_idx_in(vga_read_idx),
                .rtc_poll_ready(rtc_ready_for_read[i]),

                .idx_from_rtc(idx_fan[i]),
                .x0_from_rtc(x0_fan[i]),
                .y0_from_rtc(y0_fan[i]),

                .rtc_read(rtc_read_req[i]),
                .iter_out(iter_from_workers[i])
            );
        end
    endgenerate

    integer dbg_i;
    reg [3:0] rtc_read_req_saved;
    always @(posedge clock) begin
        rtc_read_req_saved <= rtc_read_req;
        for (dbg_i = 0; dbg_i < 4; dbg_i = dbg_i + 1)
            if (rtc_read_req_saved[dbg_i])
                $display("[%d] Sending to CW[%d] <x0=%f, y0=%f> [idx=0x%05x]",
                    $time, dbg_i, 
                    $bitstoreal(x0_fan[dbg_i]),
                    $bitstoreal(y0_fan[dbg_i]),
                    idx_fan[dbg_i]);
    end

endmodule

module VGARowColToIndexConverter
(
    input [9:0] vga_row,
    input [9:0] vga_col,

    output out_of_bounds,
    output [1:0] quad_select,
    output [16:0] idx_out
);

    wire [31:0] vga_row_ext, vga_col_ext;
    assign vga_row_ext = { { 22{ 1'b0 } }, vga_row }; 
    assign vga_col_ext = { { 22{ 1'b0 } }, vga_col }; 

    assign out_of_bounds = vga_row_ext >= 32'd600 || vga_col_ext >= 32'd800;

    wire inv_row, inv_col;
    assign inv_row = vga_row_ext < 32'd300;
    assign inv_col = vga_col_ext < 32'd400;

    wire [31:0] offset_row, offset_col;
    assign offset_row = vga_row_ext - 32'd300;
    assign offset_col = vga_col_ext - 32'd400;

    wire [31:0] inverted_offset_row, inverted_offset_col;
    assign inverted_offset_row = 32'd299 - vga_row_ext;
    assign inverted_offset_col = 32'd399 - vga_col_ext;

    assign quad_select = out_of_bounds ? 2'd0 : 
        vga_col_ext <  32'd400 && vga_row_ext <  32'd300 ? 2'd1 :
        vga_col_ext >= 32'd400 && vga_row_ext <  32'd300 ? 2'd2 :
        vga_col_ext <  32'd400 && vga_row_ext >= 32'd300 ? 2'd3 :
        vga_col_ext >= 32'd400 && vga_row_ext >= 32'd300 ? 2'd0 : 2'dx;

    wire [31:0] relative_row, relative_col;
    assign relative_row = inv_row ? inverted_offset_row : offset_row;
    assign relative_col = inv_col ? inverted_offset_col : offset_col;

    wire [31:0] idx_ext;
    RelativeRowColIndexConverter converter
    (
        .row(relative_row),
        .col(relative_col),
        .idx(idx_ext)
    );

    assign idx_out = idx_ext[16:0];

endmodule

module RelativeRowColIndexConverter
(
    input [31:0] row, 
    input [31:0] col,
    output [31:0] idx
);
    /* idx = (row * 400) + col */
    assign idx = (row << 8) + (row << 7) + (row << 4) + col;

endmodule