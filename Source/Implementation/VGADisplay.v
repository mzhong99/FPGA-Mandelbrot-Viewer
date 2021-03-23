`include "VGADisplay.vh"

module VGADisplay
(
    input clock,
    input reset_n,

    input [23:0] vram_rd_in,

    output [9:0] vram_rd_row,
    output [9:0] vram_rd_col,

    output vga_clock,
    output vga_sync_n,
    output vga_blank_n,

    output vga_hsync,
    output vga_vsync,

    output [7:0] vga_red,
    output [7:0] vga_grn,
    output [7:0] vga_blu
);

    localparam [10:0] H_VIS  = 11'd800, H_FP = 11'd56, 
                      H_SYNC = 11'd120, H_BP = 11'd64;

    localparam [10:0] V_VIS  = 11'd600, V_FP = 11'd37, 
                      V_SYNC = 11'd6,   V_BP = 11'd23;

    localparam [10:0] H_VIS_END  = H_VIS, 
                      H_FP_END   = H_VIS + H_FP, 
                      H_SYNC_END = H_VIS + H_FP + H_SYNC,
                      H_BP_END   = H_VIS + H_FP + H_SYNC + H_BP;

    localparam [10:0] V_VIS_END  = V_VIS, 
                      V_FP_END   = V_VIS + V_FP, 
                      V_SYNC_END = V_VIS + V_FP + V_SYNC,
                      V_BP_END   = V_VIS + V_FP + V_SYNC + V_BP;

    reg [10:0] horiz_it;
    reg [10:0] vert_it;

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            horiz_it <= 11'd0;
            vert_it <= 11'd0;
        end
        else begin
            if (horiz_it + 11'd1 == H_BP_END) begin
                horiz_it <= 11'd0;

                if (vert_it + 11'd1 == V_BP_END)
                    vert_it <= 11'd0;
                else
                    vert_it <= vert_it + 11'd1;
            end
            else begin
                horiz_it <= horiz_it + 11'd1;
            end
        end
    end

    /* Fetching the data of the current pixel to be drawn                     */
    /* ---------------------------------------------------------------------- */
    wire [7:0] vram_red, vram_grn, vram_blu;
    assign vram_rd_row = vert_it[9:0];
    assign vram_rd_col = horiz_it[9:0];

    wire inbounds;
    assign inbounds = horiz_it < H_VIS_END && vert_it < V_VIS_END;

    assign vram_red = vram_rd_in[23:16];
    assign vram_grn = vram_rd_in[15:8];
    assign vram_blu = vram_rd_in[7:0];

    /* If we're in drawing phase, route the VGA to receive pixel colors       */
    /* ---------------------------------------------------------------------- */
    assign vga_red = inbounds ? ~vram_red : 8'd0;
    assign vga_grn = inbounds ? ~vram_grn : 8'd0;
    assign vga_blu = inbounds ? ~vram_blu : 8'd0;

    /* Finally, generate the synchronization and clock pulses as needed       */
    /* ---------------------------------------------------------------------- */
    assign vga_hsync = horiz_it < H_FP_END || horiz_it >= H_SYNC_END;
    assign vga_vsync = vert_it  < V_FP_END || vert_it  >= H_SYNC_END;

    assign vga_sync_n = 1'b0;
    assign vga_blank_n = horiz_it < H_VIS_END && vert_it < V_VIS_END;

    assign vga_clock = clock;

endmodule
