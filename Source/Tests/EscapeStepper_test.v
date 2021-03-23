`timescale 1 ps / 1 ps
module EscapeStepper_test;

    integer ccnt;
    wire clock;

    initial 
        for (ccnt = 0; ccnt < 256; ccnt = ccnt + 1) 
            #10;

    assign clock = ccnt[0];

    real x0_in, y0_in, x_in, y_in, x2_in, y2_in;
    reg [7:0] jobid_row_in, jobid_col_in;

    wire [63:0] x0_out, y0_out, x_out, y_out, x2_out, y2_out;
    wire [7:0] jobid_row_out, jobid_col_out;
    wire escaped;

    EscapeStepper stepper
    (
        .clock(clock),

        .x0_in(x0_in), .y0_in(y0_in),
        .x2_in(x2_in), .y2_in(y2_in),
        .x_in(x_in), .y_in(y_in),

        .x0_out(x0_out), .y0_out(y0_out),
        .x2_out(x2_out), .y2_out(y2_out),
        .x_out(x_out), .y_out(y_out),

        .jobid_row_in(jobid_row_in),
        .jobid_row_out(jobid_row_out),

        .jobid_col_in(jobid_col_in),
        .jobid_col_out(jobid_col_out),

        .escaped_out(escaped)
    );

    initial begin
        #20;

        /* ------------------------------------------------------ */
        /* x_next = x^2 - y^2 + x0   = 9.0 - 16.0 + 1.5    = -5.5 */
        /* y_next = (2 * x * y) + y0 = 2 * 3.0 * 4.0 + 1.2 = 25.2 */
        /* ------------------------------------------------------ */
        x0_in = 1.5;
        y0_in = 1.2;

        x_in = 3.0;
        y_in = 4.0;

        x2_in = 9.0;
        y2_in = 16.0;

        jobid_row_in = 42;
        jobid_col_in = 24;

        #20;

        /* ------------------------------------------------------ */
        /* x_next = x^2 - y^2 + x0   = 4.0 - 9.0 - 4.2     = -9.2 */
        /* y_next = (2 * x * y) + y0 = 2 * 2.0 * 3.0 + 2.3 = 14.3 */
        /* ------------------------------------------------------ */
        x0_in = -4.2;
        y0_in = 2.3;

        x_in = 2.0;
        y_in = 3.0;

        x2_in = 4.0;
        y2_in = 9.0;

        jobid_row_in = 69;
        jobid_col_in = 96;

        #20;

        /* -------------------------------------------- */
        /* All zeros case - ensure the escape is false. */
        /* -------------------------------------------- */

        x0_in = 0.0;
        y0_in = 0.0;

        x_in = 0.0;
        y_in = 0.0;

        x2_in = 0.0;
        y2_in = 0.0;

        jobid_row_in = 201;
        jobid_col_in = 102;

        #20;

    end

endmodule