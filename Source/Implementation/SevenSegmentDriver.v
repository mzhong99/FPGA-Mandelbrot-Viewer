module SevenSegmentDriver 
(
    input [3:0] hex_digit, 
    output reg [6:0] hex_display
);

    always @(hex_digit) begin
        case (hex_digit)
            0       : hex_display = 7'b1000000;
            1       : hex_display = 7'b1111001;
            2       : hex_display = 7'b0100100;
            3       : hex_display = 7'b0110000;
            4       : hex_display = 7'b0011001;
            5       : hex_display = 7'b0010010;
            6       : hex_display = 7'b0000010;
            7       : hex_display = 7'b1111000;
            8       : hex_display = 7'b0000000;
            9       : hex_display = 7'b0010000;
            10      : hex_display = 7'b0001000;
            11      : hex_display = 7'b0000011;
            12      : hex_display = 7'b1000110;
            13      : hex_display = 7'b0100001;
            14      : hex_display = 7'b0000110;
            15      : hex_display = 7'b0001110;
            default : hex_display = 7'b0000000;
        endcase
    end

endmodule
