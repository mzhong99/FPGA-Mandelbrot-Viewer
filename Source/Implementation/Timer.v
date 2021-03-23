module Timer
    #(parameter NBITS = 32)
(
    input clock,
    input reset_n,
    input [NBITS - 1:0] threshold,
    output [NBITS - 1:0] count
);

    reg [NBITS - 1:0] state;

    always @(posedge clock or negedge reset_n)
        if (!reset_n)
            state <= threshold - { { (NBITS - 1){ 1'b0 } }, 1'b1 };
        else if (!count)
            state <= threshold - { { (NBITS - 1){ 1'b0 } }, 1'b1 };
        else
            state <= state - { { (NBITS - 1){ 1'b0 } }, 1'b1 };

    assign count = state;

endmodule
