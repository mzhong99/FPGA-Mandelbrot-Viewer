module CellWorker
(
    input clock,
    input reset_n,

    input [16:0] iter_idx_in,

    input rtc_poll_ready,
    input [16:0] idx_from_rtc,
    input [63:0] x0_from_rtc,
    input [63:0] y0_from_rtc,

    output rtc_read,
    output [7:0] iter_out
);

    localparam [7:0] ESCAPED = 8'hFF;
    localparam [16:0] IDX_NULL = 17'h1FFFF;

    /* ====================================================================== */
    /* Escape Stepper Signal I/O                                              */
    /* ====================================================================== */
    reg [63:0] x_to_stepper, x0_to_stepper, x2_to_stepper;
    reg [63:0] y_to_stepper, y0_to_stepper, y2_to_stepper;

    reg [16:0] idx_to_stepper;
    reg [7:0] iter_to_stepper;

    wire [63:0] x_from_stepper, x0_from_stepper, x2_from_stepper;
    wire [63:0] y_from_stepper, y0_from_stepper, y2_from_stepper;

    wire escaped_from_stepper;
    wire [16:0] idx_from_stepper;
    wire [7:0] iter_from_stepper;

    EscapeStepper stepper
    (
        .clock(clock),

        .x_in(x_to_stepper), .y_in(y_to_stepper),
        .x0_in(x0_to_stepper), .y0_in(y0_to_stepper),
        .x2_in(x2_to_stepper), .y2_in(y2_to_stepper),

        .idx_in(idx_to_stepper),
        .iter_in(iter_to_stepper),

        .x_out(x_from_stepper), .y_out(y_from_stepper),
        .x0_out(x0_from_stepper), .y0_out(y0_from_stepper),
        .x2_out(x2_from_stepper), .y2_out(y2_from_stepper),

        .escaped_out(escaped_from_stepper),

        .idx_out(idx_from_stepper),
        .iter_out(iter_from_stepper)
    );

    /* ====================================================================== */
    /* Auxiliary Control Logic                                                */
    /* ====================================================================== */
    reg [63:0] x_saved, x0_saved, x2_saved;
    reg [63:0] y_saved, y0_saved, y2_saved;

    reg [16:0] idx_saved;
    reg [7:0] iter_saved;
    reg escape_saved;

    /* Used for storing command to load fresh value into RTC */
    reg poll_rtc;

    /* Instant outputs from stepper - request for next has to be instant. */
    wire done_with_iter;
    assign done_with_iter = escaped_from_stepper 
        || iter_from_stepper == ESCAPED 
        || idx_from_stepper == IDX_NULL;
    assign rtc_read = done_with_iter && rtc_poll_ready;

    wire reiterating;
    assign reiterating = iter_saved < ESCAPED && !escape_saved;

    /* For use to output to escape cache when done. */
    reg wr_enable;
    reg [16:0] wr_addr;
    reg [3:0] wr_data;

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            x_saved <= 0; x0_saved <= 0; x2_saved <= 0;
            y_saved <= 0; y0_saved <= 0; y2_saved <= 0;

            x_to_stepper <= 0; x0_to_stepper <= 0; x2_to_stepper <= 0;
            y_to_stepper <= 0; y0_to_stepper <= 0; y2_to_stepper <= 0;

            idx_saved <= IDX_NULL; idx_to_stepper <= IDX_NULL;
            iter_saved <= 8'd0; iter_to_stepper <= 8'd0; 

            escape_saved <= 1'b0;
            poll_rtc <= 1'b0;
        end
        else begin
            /* STAGE ONE: Retrieve values and request x0/y0 from RTC          */
            /* -------------------------------------------------------------- */
            /* Save the immediate results from the stepper.                   */

            x_saved <= x_from_stepper; y_saved <= y_from_stepper; 
            x0_saved <= x0_from_stepper; y0_saved <= y0_from_stepper;
            x2_saved <= x2_from_stepper; y2_saved <= y2_from_stepper;

            iter_saved <= iter_from_stepper;
            idx_saved <= idx_from_stepper;

            escape_saved <= escaped_from_stepper;

            if (escaped_from_stepper && idx_from_stepper != IDX_NULL) begin
                $display("[%d] Cell worker escape: idx=0x%05x, iter=%u",
                    $time, idx_from_stepper, iter_from_stepper);
            end

            if (idx_from_stepper != IDX_NULL) begin
                if (escaped_from_stepper || iter_from_stepper == 8'hFF) begin
                    wr_enable <= 1'b1;
                    wr_addr <= idx_from_stepper;
                    wr_data <= iter_from_stepper[7:4];
                    $display("[%d] Writing to memory: idx=0x%05x, iter=%u",
                        $time, idx_from_stepper, iter_from_stepper);
                end
            end
            else begin
                wr_enable <= 1'b0;
            end

            /* Main Control Logic                                             */
            /* -------------------------------------------------------------- */
            /* CASE 1: The value you've received has either ESCAPED or is 255 */
            /*   -> Next value to be loaded should be either fetched from the */
            /*      rtc queue, or null 17'h1FFFF if queue is empty.           */
            /*   -> Save this finished value into the shader escape cache.    */
            /*                                                                */
            /* CASE 2: The value you've received must be reiterated           */
            /*   -> Next value to be loaded should be the one you just saved. */
            /* -------------------------------------------------------------- */

            if (poll_rtc) begin
                x_to_stepper <= 64'd0; x2_to_stepper <= 64'd0;
                y_to_stepper <= 64'd0; y2_to_stepper <= 64'd0;

                x0_to_stepper <= x0_from_rtc;
                y0_to_stepper <= y0_from_rtc;

                idx_to_stepper <= idx_from_rtc;
                iter_to_stepper <= 8'd0;
            end
            else if (reiterating) begin
                x_to_stepper <= x_saved; y_to_stepper <= y_saved;
                x0_to_stepper <= x0_saved; y0_to_stepper <= y0_saved;
                x2_to_stepper <= x2_saved; y2_to_stepper <= y2_saved;

                iter_to_stepper <= iter_saved;
                idx_to_stepper <= idx_saved;
            end
            else begin
                idx_to_stepper <= IDX_NULL;
            end

            poll_rtc <= done_with_iter && rtc_poll_ready;
        end
    end

    wire [3:0] rd_data;
    wire [16:0] rd_addr;
    assign rd_addr = iter_idx_in;

    RandomAccessMemory escape_cache
    ( 
        .clock(clock), 
        .wr_enable(wr_enable),

        .wr_addr(wr_addr),
        .wr_data(wr_data),

        .rd_addr(rd_addr),  
        .rd_data(rd_data)
    );

    defparam escape_cache.DATA_WIDTH = 4;
    defparam escape_cache.ADDR_WIDTH = 17;

    assign iter_out = { rd_data, 4'b0000 };

endmodule