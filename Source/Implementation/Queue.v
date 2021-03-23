module Queue
    #(parameter WIDTH = 32, LEN_NBITS = 6)
(
    input clock,

    input read,
    input write,

    input [WIDTH - 1:0] data_in,

    output full,
    output empty,

    output [WIDTH - 1:0] data_out
);

    reg [WIDTH - 1:0] data[0:(1 << LEN_NBITS) - 1];
    reg [WIDTH - 1:0] fetch;

    reg [LEN_NBITS - 1:0] write_ptr;
    reg [LEN_NBITS - 1:0] read_ptr;

    wire [LEN_NBITS - 1:0] one_ext;
    assign one_ext = { { (LEN_NBITS - 1){ 1'b0 } }, 1'b1 };

    initial begin
        write_ptr = 0;
        read_ptr = 0;
    end

    assign empty = write_ptr == read_ptr;
    assign full = write_ptr + one_ext == read_ptr;

    always @(posedge clock) begin
        if (write && !full) begin
            data[write_ptr] <= data_in;
            write_ptr <= write_ptr + one_ext;
        end

        if (read && !empty) begin
            fetch <= data[read_ptr];
            read_ptr <= read_ptr + one_ext;
        end
    end

    assign data_out = fetch;

endmodule