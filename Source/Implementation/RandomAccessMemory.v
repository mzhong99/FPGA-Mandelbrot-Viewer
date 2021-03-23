module RandomAccessMemory
    #(parameter DATA_WIDTH = 32, parameter ADDR_WIDTH = 8)
(
    input clock,
    input wr_enable,

    input [ADDR_WIDTH - 1:0] wr_addr,
    input [DATA_WIDTH - 1:0] wr_data,

    input [ADDR_WIDTH - 1:0] rd_addr,
    output [DATA_WIDTH - 1:0] rd_data
);

    reg [DATA_WIDTH - 1:0] ram[(1 << ADDR_WIDTH) - 1:0];
    reg [ADDR_WIDTH - 1:0] rd_addr_reg;
    
    always @(posedge clock) begin
        if (wr_enable)
            ram[wr_addr] <= wr_data;

        rd_addr_reg <= rd_addr;
    end

    assign rd_data = ram[rd_addr_reg];

endmodule

