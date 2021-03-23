`timescale 1ps/1ps

module LinearScaler_test;

    integer ccnt;
    wire clock;

    assign clock = ccnt[0];
    initial
        for (ccnt = 0; ccnt < 512; ccnt = ccnt + 1)
            #10;

    integer idx_in;
    real range_offset;
    real range_width;

    wire [63:0] scaled_out;

    LinearScaler stepper
    (
        .clock(clock),
        .idx_in(idx_in),
        .range_offset(range_offset),
        .range_width(range_width),
        .scaled_out(scaled_out)
    );

    initial begin
        range_offset = 2.0;
        range_width = 3.5;

        for (idx_in = 0; idx_in < 100; idx_in = idx_in + 1)
            #20;

        range_offset = -1.0;
        range_width = 5.0;

        for (idx_in = 0; idx_in < 100; idx_in = idx_in + 1)
            #20;
    end

endmodule