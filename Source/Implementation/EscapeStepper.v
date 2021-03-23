/******************************************************************************/
/* Escape Stepper Module                                                      */
/* -------------------------------------------------------------------------- */
/* @author mzhong99                                                           */
/* @version March 18, 2021                                                    */
/*                                                                            */
/* Implements one step of the escape algorithm in the Mandelbrot Set design,  */
/* using a pipeline of 39 total cycles, three multipliers, and four adders.   */
/*                                                                            */
/* The function this module specifically implements is:                       */
/*     x_next = x^2 - y^2 + x0                                                */
/*     y_next = (2 * x * y) + y0                                              */
/******************************************************************************/
module EscapeStepper
(
    input clock,

    input [63:0] x0_in,
    input [63:0] y0_in,

    input [63:0] x_in, 
    input [63:0] y_in,

    input [63:0] x2_in,
    input [63:0] y2_in,

    input [16:0] idx_in,
    input [7:0] iter_in,

    output [63:0] x0_out,
    output [63:0] y0_out,

    output [63:0] x_out,
    output [63:0] y_out,

    output [63:0] x2_out,
    output [63:0] y2_out,

    output escaped_out,

    output [16:0] idx_out,
    output [7:0] iter_out
);

    /* ====================================================================== */
    /* Helper Float Functions                                                 */
    /* ====================================================================== */
    function automatic [63:0] float_times_two(input [63:0] in);
        begin
            if (in[62:52] == 11'd0)
                float_times_two = in;
            else
                float_times_two = { in[63], in[62:52] + 11'd1, in[51:0] };
        end
    endfunction

    function automatic [63:0] float_neg(input [63:0] in);
        begin
            if (in == 64'd0)
                float_neg = 64'd0;
            else
                float_neg = { ~in[63], in[62:0] };
        end
    endfunction

    function automatic float_greater_than_4(input [63:0] in);
        reg [10:0] exponent;
        reg sign;
        begin
            sign = in[63];
            exponent = in[62:52];

            /* check if greater than 2^(1025 - 1023) == 2^2 == 4 through exp. */
            /* NOTE: the exponent bias is NO LONGER -127 and IS NOW -1023 b/c */
            /*       the number of exponent is now 11 and NOT 8 ANYMORE!!!!   */
            float_greater_than_4 = exponent >= 11'd1025 && sign == 1'b0; 
        end
    endfunction

    /* ====================================================================== */
    /* PATH 1: Computation of next y and y^2 value                            */
    /* ====================================================================== */

    /* ---------------------------------------------------------------------- */
    /* (11C) Stage 1: Multiply (2 * x * y) and save y0                        */
    /* ---------------------------------------------------------------------- */
    wire [63:0] S1_xy;
    wire [63:0] S1_two_xy;
    wire [63:0] S1_y0;

    FIFO S1_y0_saver( .clock(clock), .in(y0_in), .out(S1_y0) );
    defparam S1_y0_saver.WIDTH = 64;
    defparam S1_y0_saver.PIPELEN = 11;

    AlteraMultiplier S1_x_y_TO_xy
    ( .clock(clock), .dataa(x_in), .datab(y_in), .result(S1_xy) );

    assign S1_two_xy = float_times_two(S1_xy);

    /* ---------------------------------------------------------------------- */
    /* (14C) Stage 2: Compute y_next as (2 * x * y) + y_0                     */
    /* ---------------------------------------------------------------------- */
    wire [63:0] S2_y;

    AlteraAdder S2_two_xy_y0_TO_y_next
    ( .clock(clock), .dataa(S1_two_xy), .datab(S1_y0), .result(S2_y) );

    /* ---------------------------------------------------------------------- */
    /* (11C) Stage 3: Compute y_next^2 and save y_next                        */
    /* ---------------------------------------------------------------------- */
    wire [63:0] S3_y;
    wire [63:0] S3_y2;

    AlteraMultiplier S3_y_TO_y2
    ( .clock(clock), .dataa(S2_y), .datab(S2_y), .result(S3_y2) );

    FIFO S3_y_saver( .clock(clock), .in(S2_y), .out(S3_y) );
    defparam S3_y_saver.WIDTH = 64;
    defparam S3_y_saver.PIPELEN = 11;

    /* ---------------------------------------------------------------------- */
    /* (3C) Stage 4: Preserve all outputs for 3 more cycles                   */
    /* ---------------------------------------------------------------------- */
    wire [63:0] S4_y;
    wire [63:0] S4_y2;

    FIFO S4_y_saver( .clock(clock), .in(S3_y), .out(S4_y) );
    defparam S4_y_saver.WIDTH = 64;
    defparam S4_y_saver.PIPELEN = 3;

    FIFO S4_y2_saver( .clock(clock), .in(S3_y2), .out(S4_y2) );
    defparam S4_y2_saver.WIDTH = 64;
    defparam S4_y2_saver.PIPELEN = 3;

    /* ====================================================================== */
    /* PATH 2: Computation of next x and x^2 value                            */
    /* ====================================================================== */

    /* ---------------------------------------------------------------------- */
    /* (14C) Stage 1: Computation of x^2 - y^2, x^2 + y^2, and save x0        */
    /* ---------------------------------------------------------------------- */
    wire [63:0] minus_y2;
    wire [63:0] S1_x0;
    wire [63:0] S1_x2_plus_y2;
    wire [63:0] S1_x2_minus_y2;
    wire S1_escaped;

    assign minus_y2 = float_neg(y2_in);

    AlteraAdder S1_x2_y2_TO_x2_minus_y2
    ( .clock(clock), .dataa(x2_in), .datab(minus_y2), .result(S1_x2_minus_y2) );

    AlteraAdder S1_x2_y2_TO_x2_plus_y2
    ( .clock(clock), .dataa(x2_in), .datab(y2_in), .result(S1_x2_plus_y2) );

    FIFO S1_x0_saver( .clock(clock), .in(x0_in), .out(S1_x0) );
    defparam S1_x0_saver.WIDTH = 64;
    defparam S1_x0_saver.PIPELEN = 14;

    assign S1_escaped = float_greater_than_4(S1_x2_plus_y2);

    /* ---------------------------------------------------------------------- */
    /* (14C) Stage 2: Adding x0 to (x^2 - y^2) and saving if we've escaped    */
    /* ---------------------------------------------------------------------- */
    wire [63:0] S2_x;
    wire S2_escaped;

    AlteraAdder S2_x2_minus_y2_x0_TO_x_next
    ( .clock(clock), .dataa(S1_x0), .datab(S1_x2_minus_y2), .result(S2_x) );

    FIFO S2_escaped_saver( .clock(clock), .in(S1_escaped), .out(S2_escaped) );
    defparam S2_escaped_saver.WIDTH = 1;
    defparam S2_escaped_saver.PIPELEN = 14;

    /* ---------------------------------------------------------------------- */
    /* (11C) Stage 3: Saving escape flag, finding x_next^2, and saving x_next */
    /* ---------------------------------------------------------------------- */
    wire [63:0] S3_x;
    wire [63:0] S3_x2;
    wire S3_escaped;

    AlteraMultiplier S3_x_TO_x2
    ( .clock(clock), .dataa(S2_x), .datab(S2_x), .result(S3_x2) );

    FIFO S3_x_saver( .clock(clock), .in(S2_x), .out(S3_x) );
    defparam S3_x_saver.WIDTH = 64;
    defparam S3_x_saver.PIPELEN = 11;

    FIFO S3_escaped_saver( .clock(clock), .in(S2_escaped), .out(S3_escaped) );
    defparam S3_escaped_saver.WIDTH = 1;
    defparam S3_escaped_saver.PIPELEN = 11;

    /* ====================================================================== */
    /* PATH 3: Job ID Forwarding and Iterations Forwarding                    */
    /* ====================================================================== */

    FIFO x0_saver
    ( .clock(clock), .in(S1_x0), .out(x0_out) );
    defparam x0_saver.WIDTH = 64;
    defparam x0_saver.PIPELEN = 25;

    FIFO y0_saver
    ( .clock(clock), .in(S1_y0), .out(y0_out) );
    defparam y0_saver.WIDTH = 64;
    defparam y0_saver.PIPELEN = 28;

    FIFO idx_saver( .clock(clock), .in(idx_in), .out(idx_out) );
    defparam idx_saver.WIDTH = 17;
    defparam idx_saver.PIPELEN = 39;
    defparam idx_saver.INITIAL_BITVAL = 1'b1;

    wire [7:0] iter_saved;
    FIFO iteration_saver( .clock(clock), .in(iter_in), .out(iter_saved) );
    defparam iteration_saver.WIDTH = 8;
    defparam iteration_saver.PIPELEN = 39;
    defparam iteration_saver.INITIAL_BITVAL = 1'b1;

    assign iter_out = iter_saved != 8'hFF ? iter_saved + 8'd1 : iter_saved;

    /* ====================================================================== */
    /* OUTPUT ASSIGNMENT                                                      */
    /* ====================================================================== */
    assign x_out = S3_x;
    assign y_out = S4_y;

    assign x2_out = S3_x2;
    assign y2_out = S4_y2;

    assign escaped_out = S3_escaped;

    always @(posedge clock) begin
        if (S3_escaped && idx_out != 17'h1FFFF)
            $display("[%d] ESCAPED: idx=0x%05x, x2=%f [0x%x], y2=%f [0x%x]",
                $time, idx_out,
                $bitstoreal(x2_out), x2_out,
                $bitstoreal(y2_out), y2_out);
    end

endmodule