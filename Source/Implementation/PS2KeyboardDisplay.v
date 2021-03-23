module PS2KeyboardDisplay
(
    input clock,
    input reset_n,

    input [7:0] keyevent_in,

    output [23:0] seven_segment_hex
);

    reg [23:0] display;

    always @(posedge clock or negedge reset_n) 
        if (!reset_n) 
            display <= 24'd0;
        else if (keyevent_in)
            display <= { display[15:0], keyevent_in };

    assign seven_segment_hex = display;

endmodule
