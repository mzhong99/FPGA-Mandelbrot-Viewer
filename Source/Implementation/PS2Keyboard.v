/******************************************************************************/
/* PS/2 Keyboard Interface Module                                             */
/* -------------------------------------------------------------------------- */
/* Implements a module which acts as a device-to-host data receiver. In the   */
/* PS/2 communications interface, the device drives the shared PS/2 clock to  */
/* begin sending a packet. The device writes data when the clock is HIGH, and */
/* the host is able to read from the data line when the clock is LOW. The     */
/* packet order is transferred like this:                                     */
/*                                                                            */
/*     +-------+                                                              */
/*     | START | --> Always ZERO                                              */
/*     +-------+                                                              */
/*     | DATA0 | --> LSB is sent FIRST                                        */
/*     +-------+                                                              */
/*     | DATA1 |                                                              */
/*     +-------+                                                              */
/*     | DATA2 |                                                              */
/*     +-------+                                                              */
/*     | DATA3 |                                                              */
/*     +-------+                                                              */
/*     | DATA4 |                                                              */
/*     +-------+                                                              */
/*     | DATA5 |                                                              */
/*     +-------+                                                              */
/*     | DATA6 |                                                              */
/*     +-------+                                                              */
/*     | DATA7 |                                                              */
/*     +-------+                                                              */
/*     |  PAR  | --> Follows ODD parity, s.t. the data bits and parity bit    */
/*     +-------+     combined have an ODD number of 1's.                      */
/*     |  STOP | --> Always ONE                                               */
/*     +-------+                                                              */
/*                                                                            */
/******************************************************************************/

module PS2Keyboard
(
    input clock,
    input reset_n,

    input ps2_clock,
    input ps2_data,

    output [255:0] keytable_out,
    output reg [7:0] keyevent_out
);

    /* Edge detector - since the PS/2 and the De1-SoC are on different clock  */
    /*                 domains, to transfer signals we use edge detection.    */
    /* ---------------------------------------------------------------------- */
    wire ps2_clock_negedge;

    EdgeDetector detector
    (
        .clock(clock), 
        .reset_n(reset_n), 
        .raw(ps2_clock), 
        .rise(), 
        .fall(ps2_clock_negedge)
    );

    reg [10:0] data_raw;
    reg [3:0] iter;

    wire [7:0] next_packet;
    assign next_packet = data_raw[8:1];

    reg [7:0] data_parsed;
    reg [255:0] keytable;

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            iter <= 4'd0;
            data_parsed <= 8'd0;
            keytable <= 255'd0;
        end
        else if (ps2_clock_negedge) begin
            data_raw[iter] <= ps2_data;
            if (iter == 4'd10) begin
                keytable[next_packet] = data_parsed != 8'hF0;
                data_parsed <= next_packet;
            end
            iter <= iter == 4'd10 ? 4'd0 : iter + 4'd1;
        end
    end

    assign keytable_out = keytable;

    /* Key event generation - most recent key pressed should be event output  */
    /* ---------------------------------------------------------------------- */
    wire [255:0] keytaps;


    genvar detect_it;
    generate
        for (detect_it = 0; detect_it < 256; detect_it = detect_it + 1) 
        begin: detector_block
            EdgeDetector detector
            ( 
                .clock(clock), 
                .reset_n(reset_n), 
                .raw(keytable[detect_it]), 
                .rise(keytaps[detect_it]),
                .fall()
            );
            defparam detector.init_level = 1'b0;
        end
    endgenerate

    integer i;
    always @* begin
        keyevent_out = 8'h00;
        for (i = 0; i < 256; i = i + 1) 
            if (keytaps[i])
                keyevent_out = i[7:0];
    end

endmodule
