module RandomAccessMemory_test;

    reg clock;
    reg clock_done;

    initial begin
        clock = 1'b0;
        clock_done = 1'b0;
        while (!clock_done)
            #10 clock = ~clock;
    end

    reg [3:0] wr_addr, rd_addr;
    reg [7:0] wr_data;
    reg wr_enable;

    wire [7:0] rd_data;

    RandomAccessMemory mem
    (
        .clock(clock),
        .wr_enable(wr_enable),

        .wr_addr(wr_addr),
        .wr_data(wr_data),

        .rd_addr(rd_addr),
        .rd_data(rd_data)
    );

    defparam mem.DATA_WIDTH = 8;
    defparam mem.ADDR_WIDTH = 4;

    initial begin
        
        wr_enable = 1'b0;
        rd_addr = 4'h0;
        #10;

        wr_enable = 1'b1;
        wr_addr = 4'hA;
        wr_data = 8'hFF;
        #20;

        wr_enable = 1'b0;
        rd_addr = 4'hA;
        #20;

        clock_done = 1'b1;
    end

endmodule