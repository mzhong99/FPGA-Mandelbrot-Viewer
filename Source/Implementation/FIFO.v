module FIFO
    #(parameter WIDTH = 32, PIPELEN = 4, INITIAL_BITVAL = 1'b0)
(
    input clock,

    input [WIDTH - 1:0] in,
    output [WIDTH - 1:0] out
);
    reg [(WIDTH * PIPELEN) - 1:0] values;
    initial values = { (WIDTH * PIPELEN){ INITIAL_BITVAL } };

    always @(posedge clock)
        values <= (values << WIDTH) | in;

    assign out = values[(WIDTH * PIPELEN) - 1:(WIDTH * PIPELEN) - WIDTH];
    
endmodule