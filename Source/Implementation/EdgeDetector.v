module EdgeDetector
    #(parameter init_level = 1'b1)
(
    input clock,
    input reset_n,
    input raw,
    output rise,
    output fall
);

    reg [1:0] window;

    always @(posedge clock or negedge reset_n)
        if (!reset_n)
            window <= { (2){ init_level } };
        else
            window <= { window[0], raw };

    assign rise = window == 2'b01;
    assign fall = window == 2'b10;

endmodule
