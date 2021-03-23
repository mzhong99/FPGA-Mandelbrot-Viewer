`timescale 1ps/1ps

module Queue_test;

    integer ccnt;
    wire clock;

    assign clock = ccnt[0];
    initial
        for (ccnt = 0; ccnt < 8192; ccnt = ccnt + 1)
            #10;

    reg read, write;
    reg [31:0] data_in;

    wire [31:0] data_out;
    wire full, empty;

    Queue queue
    (
        .clock(clock),

        .read(read),
        .write(write),

        .data_in(data_in),

        .full(full),
        .empty(empty),

        .data_out(data_out)
    );
    defparam queue.LEN_NBITS = 4;

    integer i;
    
    initial begin

        read = 1'b0;
        write = 1'b1;
        for (i = 0; i < (2 << 4) + 5; i = i + 1) begin
            data_in = i + 1;
            #20;
        end

        write = 1'b0;
        read = 1'b1;
        for (i = 0; i < (2 << 4) + 5; i = i + 1)
            #20;

        write = 1'b1;
        read = 1'b0;
        for (i = 0; i < (2 << 4) + 5; i = i + 1) begin
            data_in = i + 1;
            #20;
        end

        write = 1'b0;
        read = 1'b1;
        for (i = 0; i < (2 << 4) + 5; i = i + 1)
            #20;
    end

endmodule