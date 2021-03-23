`timescale 1ps/1ps
module MandelbrotComputer_test;

    reg clock;
    reg clock_done;

    initial begin
        clock = 1'b0;
        clock_done = 1'b0;
        while (!clock_done)
            #10 clock = ~clock;

    end

    reg reset_n;
    reg [10:0] vga_row, vga_col;

    MandelbrotComputer mandelbrot
    (
        .clock(clock),
        .reset_n(reset_n),

        .zoom_in(1'b0),
        .zoom_out(1'b0),

        .pan_up(1'b0),
        .pan_down(1'b0),
        .pan_left(1'b0),
        .pan_right(1'b0),

        .vga_row_in(vga_row[9:0]),
        .vga_col_in(vga_col[9:0]),

        .vram_out()
    );

    integer i;

    initial begin
        reset_n = 1'b0;
        #5;
        reset_n = 1'b1;
        #5;

        for (i = 0; i < 256; i = i + 1)
            #20;

        repeat (255)
            for (vga_row = 300; vga_row < 301; vga_row = vga_row + 1)
                for (vga_col = 400; vga_col < 420; vga_col = vga_col + 1)
                    #20;

        clock_done = 1'b1;
        #20;
    end

endmodule