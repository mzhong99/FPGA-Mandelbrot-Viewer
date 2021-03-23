`timescale 1ps/1ps

module ResolutionTranslationCache_test;

    integer ccnt;
    wire clock;

    assign clock = ccnt[0];
    initial
        for (ccnt = 0; ccnt < 1024; ccnt = ccnt + 1)
            #10;

    reg reset_n;
    reg [3:0] read_req;
    real x_center_in, y_center_in, width_in, height_in;

    wire [3:0] ready_for_read;
    wire [16:0] idx_out[0:3];
    wire [63:0] x0_out[0:3]; 
    wire [63:0] y0_out[0:3];

    ResolutionTranslationCache cache
    (
        .clock(clock),
        .reset_n(reset_n),

        .x_center_in(x_center_in),
        .y_center_in(y_center_in),
        .width_in(width_in),
        .height_in(height_in),

        .read_req(read_req),
        .ready_for_read(ready_for_read),

        .idx_out({ idx_out[3], idx_out[2], idx_out[1], idx_out[0] }),
        .x0_out({ x0_out[3], x0_out[2], x0_out[1], x0_out[0] }),
        .y0_out({ y0_out[3], y0_out[2], y0_out[1], y0_out[0] })
    );

    integer i;

    initial begin
        x_center_in = 1.0;
        y_center_in = 1.0;

        width_in = 2.5;
        height_in = 2.5;

        read_req = 4'b0000;

        reset_n = 1'b0;
        #20;

        reset_n = 1'b1;

        while (ready_for_read != 4'b1111)
            #20;
        
        #120;

        for (i = 0; i < 512; i = i + 1) begin
            read_req = ready_for_read; 
            #20;
        end

        read_req = 4'b0000;
    end

endmodule