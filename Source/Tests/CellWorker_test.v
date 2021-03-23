`timescale 1ps/1ps
module CellWorker_test;

    reg clock, reset_n;
    reg simulation_done;

    initial begin
        clock = 1'b0;
        simulation_done = 1'b0;

        while (!simulation_done) begin
            clock = ~clock;
            #10;
        end
    end

    wire [144:0] queue_data_in, queue_data_out;
    wire queue_full, queue_empty, queue_read;

    real x0_to_queue, y0_to_queue;
    reg [16:0] idx_to_queue;

    reg queue_write;

    wire [63:0] x0_in, y0_in;
    assign x0_in = $realtobits(x0_to_queue);
    assign y0_in = $realtobits(y0_to_queue);

    wire [63:0] x0_from_queue, y0_from_queue;
    wire [16:0] idx_from_queue;

    wire x0_queue_full, x0_queue_empty;
    wire y0_queue_full, y0_queue_empty;

    Queue rtc_x0_queue
    (
        .clock(clock),
        .data_in(x0_in),
        .data_out(x0_from_queue),
        .read(queue_read),
        .write(queue_write),

        .full(x0_queue_full), 
        .empty(x0_queue_empty)
    );
    defparam rtc_x0_queue.WIDTH = 64;
    defparam rtc_x0_queue.LEN_NBITS = 3;

    Queue rtc_y0_queue
    (
        .clock(clock),
        .data_in(y0_in),
        .data_out(y0_from_queue),
        .read(queue_read),
        .write(queue_write),

        .full(y0_queue_full), 
        .empty(y0_queue_empty)
    );
    defparam rtc_y0_queue.WIDTH = 64;
    defparam rtc_y0_queue.LEN_NBITS = 3;

    Queue rtc_idx_queue
    (
        .clock(clock),
        .data_in(idx_to_queue),
        .data_out(idx_from_queue),
        .read(queue_read),
        .write(queue_write),

        .full(queue_full),
        .empty(queue_empty)
    );
    defparam rtc_idx_queue.WIDTH = 17;
    defparam rtc_idx_queue.LEN_NBITS = 3;

    reg [16:0] iter_idx_in;
    wire [7:0] iter_out;

    CellWorker dut
    (
        .clock(clock),
        .reset_n(reset_n),

        .iter_idx_in(iter_idx_in),
        .iter_out(iter_out),

        .rtc_poll_ready(!queue_empty),
        .idx_from_rtc(idx_from_queue),
        .x0_from_rtc(x0_from_queue),
        .y0_from_rtc(y0_from_queue),

        .rtc_read(queue_read)
    );

    reg queue_read_saved, queue_read_saved2;
    reg [16:0] idx_saved;

    always @(posedge clock) begin
        if (queue_write)
            $display("[%d] [Queue Insert] <x0=%f, y0=%f, idx_in=0x%05x>",
                $time, 
                $bitstoreal(x0_in), 
                $bitstoreal(y0_in), 
                idx_to_queue);

        queue_read_saved <= queue_read;
        queue_read_saved2 <= queue_read_saved;

        if (queue_read_saved) begin
            $display("[%d] [Queue Pop] <x0=%f, y0=%f, idx=0x%05x>",
                $time, 
                $bitstoreal(x0_from_queue), 
                $bitstoreal(y0_from_queue), 
                idx_from_queue);
        end

        if (queue_read_saved2) begin
            $display("[%d] [Stepper Insert] [0x%05x] <x0=%f, y0=%f>, <x=%f, y=%f>, iter=%u",
                $time,
                dut.idx_to_stepper,
                $bitstoreal(dut.x0_to_stepper),
                $bitstoreal(dut.y0_to_stepper),
                $bitstoreal(dut.x_to_stepper),
                $bitstoreal(dut.y_to_stepper),
                dut.iter_to_stepper);
        end
        
        if (dut.idx_from_stepper != 17'h1FFFF) 
            $display("[%d] [Stepper Iteration] [0x%05x] <x0=%f, y0=%f> <x=%f, y=%f>, iter=%u",
                $time,
                dut.idx_from_stepper,
                $bitstoreal(dut.x0_from_stepper), 
                $bitstoreal(dut.y0_from_stepper),
                $bitstoreal(dut.x_from_stepper), 
                $bitstoreal(dut.y_from_stepper),
                dut.iter_from_stepper);
    end

    reg seen_dead, seen_beef, seen_1337;

    reg [7:0] iter_rx;
    reg [16:0] idx_rx;
    reg escaped_rx;

    // initial begin
    //     $monitor("[%d] [VRAM_GET] idx=%u, iter=0x%02x", 
    //         $time, iter_idx_in, iter_out);
    // end

    initial begin
        seen_dead = 1'b0;
        seen_beef = 1'b0;
        seen_1337 = 1'b0;
        iter_idx_in = 17'h1FFFF;
        queue_write = 1'b0;

        reset_n = 1'b0; #10;
        reset_n = 1'b1; #10;

        x0_to_queue = 0.0;
        y0_to_queue = 0.0;
        idx_to_queue = 17'h0DEAD;
        queue_write = 1'b1;
        #20;

        x0_to_queue = -2.0;
        y0_to_queue = 1.0;
        idx_to_queue = 17'h0BEEF;
        queue_write = 1'b1;
        #20;

        x0_to_queue = 0.4;
        y0_to_queue = 0.0;
        idx_to_queue = 17'h01337;
        queue_write = 1'b1;
        #20;

        queue_write = 1'b0;
        #20;

        while (!seen_dead || !seen_beef || !seen_1337) 
        begin
            idx_rx = dut.idx_from_stepper;
            iter_rx = dut.iter_from_stepper;
            escaped_rx = dut.escaped_from_stepper;

            if ((escaped_rx || iter_rx == 8'hFF) && idx_rx != 17'h1FFFF) begin
                $display("[%d] Found <%05x>, escaped=%d, iter=%u", 
                    $time, idx_rx, escaped_rx, iter_rx);

                if (idx_rx == 17'h0DEAD)
                    seen_dead = 1'b1;

                if (idx_rx == 17'h0BEEF)
                    seen_beef = 1'b1;

                if (idx_rx == 17'h01337)
                    seen_1337 = 1'b1;
            end

            #20;
        end

        #160;

        iter_idx_in = 17'h0DEAD; #40;
        $display("[%d] [VRAM_GET] idx=%u, iter=0x%02x", $time, iter_idx_in, iter_out);

        iter_idx_in = 17'h0BEEF; #40;
        $display("[%d] [VRAM_GET] idx=%u, iter=0x%02x", $time, iter_idx_in, iter_out);

        iter_idx_in = 17'h01337; #40;
        $display("[%d] [VRAM_GET] idx=%u, iter=0x%02x", $time, iter_idx_in, iter_out);

        simulation_done = 1'b1;
        #20;
    end

endmodule