module ViewController
(
    input clock,
    input reset_n,

    input pan_up,
    input pan_down,

    input pan_left,
    input pan_right,

    input zoom_in,
    input zoom_out,

    output reg [63:0] x_center,
    output reg [63:0] y_center,

    output reg [63:0] width,
    output reg [63:0] height
);

    /* Default variables for potential asynchronous reset                     */
    /* ---------------------------------------------------------------------- */
    localparam DEFAULT_HEIGHT = 64'h3FF8000000000000;   /* 2.0 */
    localparam DEFAULT_WIDTH = 64'h4000000000000000;    /* 1.5 */

    localparam DEFAULT_X_CENTER = 64'h0;
    localparam DEFAULT_Y_CENTER = 64'h0;

    wire [31:0] poll_timer_count;

    Timer poll_timer
    (
        .clock(clock),
        .reset_n(reset_n),
        .threshold(32'd833333),
        .count(poll_timer_count)
    );

    wire [63:0] x_center_from_panner, y_center_from_panner;
    wire [63:0] width_from_zoomer, height_from_zoomer;
    wire [63:0] divided_width, divided_height;

    ViewZoomer2D zoomer
    (
        .clock(clock),

        .width_in(width),
        .height_in(height),

        .zoom_in(zoom_in),
        .zoom_out(zoom_out),

        .width_out(width_from_zoomer),
        .height_out(height_from_zoomer),

        .divided_width_out(divided_width),
        .divided_height_out(divided_height)
    );

    ViewPanner2D panner
    (
        .clock(clock),

        .x_in(x_center),
        .y_in(y_center),

        .divided_width_in(divided_width),
        .divided_height_in(divided_height),

        .pan_up(pan_up),
        .pan_down(pan_down),
        .pan_left(pan_left),
        .pan_right(pan_right),

        .x_out(x_center_from_panner),
        .y_out(y_center_from_panner)
    );

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            x_center <= DEFAULT_X_CENTER;
            y_center <= DEFAULT_Y_CENTER;

            width <= DEFAULT_WIDTH;
            height <= DEFAULT_HEIGHT;
        end
        else begin
            if (!poll_timer_count) begin
                x_center <= x_center_from_panner;
                y_center <= y_center_from_panner;

                width <= width_from_zoomer;
                height <= height_from_zoomer;
            end
        end
    end

endmodule

module ViewZoomer2D
(
    input clock,

    input [63:0] width_in,
    input [63:0] height_in,

    input zoom_in,
    input zoom_out,

    output [63:0] width_out,
    output [63:0] height_out,

    output [63:0] divided_width_out,
    output [63:0] divided_height_out
);

    function automatic [63:0] divide_by_64(input [63:0] in);
        begin
            divide_by_64 = { in[63], (in[62:52] - 11'd6), in[51:0] };
        end
    endfunction

    localparam ZOOM_IN_SCALER = 64'h3fefeb851eb851ec;
    localparam ZOOM_OUT_SCALER = 64'h3ff00a440290b773;
    localparam ZOOM_NOSCALE = 64'h3ff0000000000000;

    wire [63:0] scaler;
    assign scaler = zoom_in  ? ZOOM_IN_SCALER  :
                    zoom_out ? ZOOM_OUT_SCALER : ZOOM_NOSCALE;

    AlteraMultiplier x_scaler
    ( .clock(clock), .dataa(width_in), .datab(scaler), .result(width_out) );

    AlteraMultiplier y_scaler
    ( .clock(clock), .dataa(height_in), .datab(scaler), .result(height_out) );

    assign divided_width_out = divide_by_64(width_out);
    assign divided_height_out = divide_by_64(height_out);

endmodule

module ViewPanner2D
(
    input clock,

    input [63:0] x_in,
    input [63:0] y_in,

    input [63:0] divided_width_in,
    input [63:0] divided_height_in,

    input pan_up,
    input pan_down,
    input pan_left,
    input pan_right,

    output [63:0] x_out,
    output [63:0] y_out
);

    wire [63:0] x_delta;
    wire [63:0] y_delta;

    function automatic [63:0] minus_double(input [63:0] in);
        begin
            minus_double = { ~in[63], in[62:0] };
        end
    endfunction

    assign x_delta = pan_right ? divided_width_in               :
                     pan_left  ? minus_double(divided_width_in) : 64'd0;

    assign y_delta = pan_down ? divided_height_in               :
                     pan_up   ? minus_double(divided_height_in) : 64'd0;

    AlteraAdder x_offsetter
    ( .clock(clock), .dataa(x_in), .datab(x_delta), .result(x_out) );

    AlteraAdder y_offsetter
    ( .clock(clock), .dataa(y_in), .datab(y_delta), .result(y_out) );

endmodule