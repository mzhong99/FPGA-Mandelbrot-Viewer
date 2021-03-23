module Counter2D 
    #(parameter MAXROW = 300, parameter MAXCOL = 400, parameter MAXIDX = 120000)
(
    input clock,
    input reset_n,
    input increment,

    output reg [31:0] row,
    output reg [31:0] col,
    output reg [31:0] idx
);

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            row <= 0;
            col <= 0;
            idx <= 0;
        end
        else if (increment) begin
            if (col + 32'd1 == MAXCOL) begin
                col <= 0;

                if (row + 32'd1 == MAXROW) begin
                    row <= 0;
                    idx <= 0;
                end
                else begin
                    idx <= idx + 32'd1;
                    row <= row + 32'd1;
                end
            end
            else begin
                col <= col + 32'd1;
                idx <= idx + 32'd1;
            end
        end
    end

endmodule