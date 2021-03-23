module ResolutionTranslationCache 
(
    input clock,
    input reset_n,

    input [63:0] x_center_in,           /* 64-bit double */
    input [63:0] y_center_in,           /* 64-bit double */
    input [63:0] width_in,              /* 64-bit double */
    input [63:0] height_in,             /* 64-bit double */

    input [3:0] read_req,           /* concatenated all queue read requests   */

    output [3:0] ready_for_read,    /* concatenated all valid read out flags  */

    output [67:0] idx_out,          /* concatenated all idx outputs together  */
    output [255:0] x0_out,          /* concatenated all x0 outputs together   */
    output [255:0] y0_out           /* concatenated all y0 outputs together   */
);

    localparam MAXROW = 300;
    localparam MAXCOL = 400;

    localparam INV_MAXROW = 64'h3F6B4E81B4E81B4F;    /* 0.0033333333... */
    localparam INV_MAXCOL = 64'h3F647AE147AE147B;    /* 0.0025 */

    localparam QUEUE_LEN_NBITS = 3;
    localparam QUEUE_LEN = (1 << QUEUE_LEN_NBITS) - 1;
    localparam QUEUE_WIDTH = 145;   /* x0, y0, and the idx */

    /* Control Logic: Multiplex quadrant inputs into the RTC Processor        */
    /* ---------------------------------------------------------------------- */
    reg [1:0] quadrant;
    integer nbuffer[0:3];

    /* Quadrant Divison Setup                                                 */
    /* ---------------------------------------------------------------------- */

    /* -- Queue I/O -- */
    wire [3:0] queue_full;
    wire [3:0] queue_empty;
    wire [3:0] queue_write;

    reg [63:0] x0_to_queue[0:3];
    reg [63:0] y0_to_queue[0:3];
    reg [16:0] idx_to_queue[0:3];

    wire [63:0] x0_from_queue[0:3];
    wire [63:0] y0_from_queue[0:3];
    wire [16:0] idx_from_queue[0:3];

    /* -- Counter I/O -- */
    wire [31:0] idx_iters_32bit[0:3];
    wire [31:0] row_iters[0:3];
    wire [31:0] col_iters[0:3];
    wire [3:0] increment; 

    /* -- Output assignment for x0 and y0 -- */
    assign x0_out = 
    { x0_from_queue[3], x0_from_queue[2], x0_from_queue[1], x0_from_queue[0] };

    assign y0_out = 
    { y0_from_queue[3], y0_from_queue[2], y0_from_queue[1], y0_from_queue[0] };

    assign idx_out =
    { idx_from_queue[3], idx_from_queue[2], idx_from_queue[1], idx_from_queue[0] };

    assign ready_for_read = ~queue_empty;

    generate
        genvar quad_i;
        for (quad_i = 0; quad_i < 4; quad_i = quad_i + 1) begin: quad_block
            Counter2D counter
            (
                .clock(clock),
                .reset_n(reset_n),
                .increment(increment[quad_i]),
                .row(row_iters[quad_i]),
                .col(col_iters[quad_i]),
                .idx(idx_iters_32bit[quad_i])
            );

            Queue x0_queue
            (
                .clock(clock),

                .read(read_req[quad_i]),
                .full(),
                .empty(),
                .write(queue_write[quad_i]),

                .data_in(x0_to_queue[quad_i]),
                .data_out(x0_from_queue[quad_i])
            );

            defparam x0_queue.WIDTH = 64;
            defparam x0_queue.LEN_NBITS = QUEUE_LEN_NBITS;

            Queue y0_queue
            (
                .clock(clock),

                .read(read_req[quad_i]),
                .full(),
                .empty(),
                .write(queue_write[quad_i]),

                .data_in(y0_to_queue[quad_i]),
                .data_out(y0_from_queue[quad_i])
            );

            defparam y0_queue.WIDTH = 64;
            defparam y0_queue.LEN_NBITS = QUEUE_LEN_NBITS;

            Queue idx_queue
            (
                .clock(clock),

                .read(read_req[quad_i]),
                .full(queue_full[quad_i]),
                .empty(queue_empty[quad_i]),
                .write(queue_write[quad_i]),

                .data_in(idx_to_queue[quad_i]),
                .data_out(idx_from_queue[quad_i])
            );

            defparam idx_queue.WIDTH = 17;
            defparam idx_queue.LEN_NBITS = QUEUE_LEN_NBITS;
        end
    endgenerate

    wire rtc_compute_next;
    assign rtc_compute_next = nbuffer[quadrant] < QUEUE_LEN;

    assign increment = rtc_compute_next << quadrant;

    reg [2:0] quad_i3;
    reg rtc_pop_next[0:3];
    always @* begin
        for (quad_i3 = 0; quad_i3 < 3'd4; quad_i3 = quad_i3 + 3'd1)
            rtc_pop_next[quad_i3] = read_req[quad_i3] 
                && !queue_empty[quad_i3] 
                && nbuffer[quad_i3] > 0;
    end

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            quadrant <= 2'd0;
            nbuffer[0] <= 0;
            nbuffer[1] <= 0;
            nbuffer[2] <= 0;
            nbuffer[3] <= 0;
        end
        else begin
            if (rtc_compute_next && !rtc_pop_next[quadrant])
                nbuffer[quadrant] <= nbuffer[quadrant] + 1;

            if (rtc_pop_next[0]) 
                nbuffer[0] <= nbuffer[0] - 1;

            if (rtc_pop_next[1]) 
                nbuffer[1] <= nbuffer[1] - 1;

            if (rtc_pop_next[2]) 
                nbuffer[2] <= nbuffer[2] - 1;

            if (rtc_pop_next[3]) 
                nbuffer[3] <= nbuffer[3] - 1;

            quadrant <= quadrant + 2'd1;
        end
    end

    /* RTC Processor outputs and saved row / cols                             */
    /* ---------------------------------------------------------------------- */
    wire [16:0] idx_to_processor;
    wire [31:0] row_to_processor;
    wire [31:0] col_to_processor;

    assign idx_to_processor = 
        rtc_compute_next ? idx_iters_32bit[quadrant][16:0] : 17'h1FFFF;
    assign row_to_processor = row_iters[quadrant];
    assign col_to_processor = col_iters[quadrant];

    wire [63:0] x0_from_processor;
    wire [63:0] y0_from_processor;
    wire [16:0] idx_from_processor;
    wire [1:0] quad_from_processor;

    RTC_Processor processor
    (
        .clock(clock), 

        .x_center_in(x_center_in), 
        .y_center_in(y_center_in),

        .width_in(width_in),
        .height_in(height_in),

        .row_in(row_to_processor),
        .col_in(col_to_processor),
        .idx_in(idx_to_processor),
        .quad_in(quadrant),

        .x0_out(x0_from_processor),
        .y0_out(y0_from_processor),
        .idx_out(idx_from_processor),
        .quad_out(quad_from_processor)
    );

    defparam processor.MAXROW = MAXROW;
    defparam processor.MAXCOL = MAXCOL;

    defparam processor.INV_MAXROW = INV_MAXROW;
    defparam processor.INV_MAXCOL = INV_MAXCOL;

    wire single_write_flag;
    assign single_write_flag = idx_from_processor != 17'h1FFFF;

    assign queue_write = single_write_flag << quad_from_processor;

    reg [2:0] quad_i2;
    always @* begin
        for (quad_i2 = 0; quad_i2 < 3'd4; quad_i2 = quad_i2 + 3'd1) begin
            x0_to_queue[quad_i2] = 0;
            y0_to_queue[quad_i2] = 0;
            idx_to_queue[quad_i2] = 0;
        end

        x0_to_queue[quadrant] = x0_from_processor;
        y0_to_queue[quadrant] = y0_from_processor;
        idx_to_queue[quadrant] = idx_from_processor;
    end

endmodule

/******************************************************************************/
/* RTC Processor Module                                                       */
/* -------------------------------------------------------------------------- */
/* @author mzhong99                                                           */
/* @version March 19, 2021                                                    */
/*                                                                            */
/* A pipelined implementation which converts row and column indices into      */
/* corresponding x and y equivalent coordinates, in 36 clock cycles.          */
/******************************************************************************/
module RTC_Processor
#(
    parameter MAXROW = 300,
    parameter MAXCOL = 400,

    parameter INV_MAXROW = 64'h3F6B4E81B4E81B4F,
    parameter INV_MAXCOL = 64'h3F647AE147AE147B
)
(
    input clock,

    input [63:0] x_center_in,
    input [63:0] y_center_in,

    input [63:0] width_in,
    input [63:0] height_in,

    input [31:0] row_in,
    input [31:0] col_in,
    input [16:0] idx_in,
    input [1:0] quad_in,

    output [63:0] x0_out,
    output [63:0] y0_out,
    output [16:0] idx_out,
    output [1:0] quad_out
);
    wire [63:0] signed_width;
    wire [63:0] signed_height;

    assign signed_width = { quad_in[0], width_in[62:0] };
    assign signed_height = { quad_in[1], height_in[62:0] };

    FIFO idx_saver( .clock(clock), .in(idx_in), .out(idx_out) );
    defparam idx_saver.WIDTH = 17;
    defparam idx_saver.PIPELEN = 36;
    defparam idx_saver.INITIAL_BITVAL = 1'b1;

    FIFO quad_saver( .clock(clock), .in(quad_in), .out(quad_out) );
    defparam quad_saver.WIDTH = 2;
    defparam quad_saver.PIPELEN = 36;

    LinearScaler xscaler
    ( 
        .clock(clock), 
        .idx_in(col_in), 

        .range_offset(x_center_in),
        .range_width(signed_width),

        .scaled_out(x0_out)
    );

    defparam xscaler.INV_MAXIDX = INV_MAXCOL;

    LinearScaler yscaler
    (
        .clock(clock),
        .idx_in(row_in),

        .range_offset(y_center_in),
        .range_width(signed_height),

        .scaled_out(y0_out)
    );

    defparam yscaler.INV_MAXIDX = INV_MAXROW;

endmodule

/******************************************************************************/
/* Linear Scaler Module                                                       */
/* -------------------------------------------------------------------------- */
/* @author mzhong99                                                           */
/* @version March 19, 2021                                                    */
/*                                                                            */
/* Implements the result of x = x0 + (idx * RANGE / MAX_IDX) using one        */
/* multiplier and one adder, in a total of 36 cycles.                         */
/*                                                                            */
/* By default, INV_MAXIDX is 0.01, represented in double-precision hex. Also, */
/* the range offset is NOT pipelined - this should cascade and save properly  */
/* after a few rounds of garbage.                                             */
/*                                                                            */
/* For some reason, under simulation, the actual latency is 35 cycles and not */
/* 36 - I have no idea why lol                                                */
/*     I KNOW WHY NOW - it's because the result has the POTENTIAL TO COME OUT */
/*                      EARLY but doesn't always come out a cycle early.      */
/******************************************************************************/
module LinearScaler
    #(parameter [63:0] INV_MAXIDX = 64'h3F847AE147AE147B)
(
    input clock,

    input [31:0] idx_in,
    input [63:0] range_offset,
    input [63:0] range_width,

    output [63:0] scaled_out
);
    /* ---------------------------------------------------------------------- */
    /* (11C) Stage 1: Convert the index into a float and compute slope M      */
    /* ---------------------------------------------------------------------- */
    wire [63:0] S1_m;
    wire [63:0] S1_idx_presave;
    wire [63:0] S1_idx;
    wire [63:0] S1_range_width;

    AlteraIntToDoubleConverter typecaster
    ( .clock(clock), .dataa(idx_in), .result(S1_idx_presave) );

    FIFO S1_idx_saver
    ( .clock(clock), .in(S1_idx_presave), .out(S1_idx) );
    defparam S1_idx_saver.WIDTH = 64;
    defparam S1_idx_saver.PIPELEN = 5;

    FIFO S1_range_width_saver
    ( .clock(clock), .in(range_width), .out(S1_range_width) );
    defparam S1_range_width_saver.WIDTH = 64;
    defparam S1_range_width_saver.PIPELEN = 5;

    AlteraMultiplier S1_TO_m
    ( .clock(clock), .dataa(INV_MAXIDX), .datab(S1_range_width), .result(S1_m) );

    /* ---------------------------------------------------------------------- */
    /* (11C) Stage 2: Multiply m and the float-converted idx together.        */
    /* ---------------------------------------------------------------------- */
    wire [63:0] S2_delta_range;

    AlteraMultiplier S2_TO_delta_range
    ( .clock(clock), .dataa(S1_m), .datab(S1_idx), .result(S2_delta_range) );

    /* ---------------------------------------------------------------------- */
    /* (14C) Stage 3: Add the range offset to the delta range                 */
    /* ---------------------------------------------------------------------- */
    AlteraAdder S3_TO_scaled_out
    ( 
        .clock(clock), 
        .dataa(S2_delta_range), 
        .datab(range_offset), 
        .result(scaled_out)
    );

endmodule