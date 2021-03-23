module Button
(
    input clock,
    input reset_n,
    input gpio,
    output pulse
);

    localparam LOW = 2'b00, POSEDGE = 2'b01, HIGH = 2'b11, NEGEDGE = 2'b10;
    reg [1:0] state;

    always @(posedge clock or negedge reset_n)
        if (!reset_n)
            state <= HIGH;
        else 
            state <= { state[0], gpio };

    assign pulse = state == NEGEDGE;

endmodule
