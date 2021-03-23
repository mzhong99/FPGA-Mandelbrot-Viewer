`include "PS2KeyboardScanCodes.vh"
`include "VGADisplay.vh"

module PeripheralsDemo
(
    input CLOCK_50, 

    input [3:0] KEY, 
    input [9:0] SW, 

    input PS2_CLK,
    input PS2_DAT,

    output [7:0] VGA_RED,
    output [7:0] VGA_GRN,
    output [7:0] VGA_BLU,

    output VGA_HSYNC,
    output VGA_VSYNC,

    output VGA_CLK,
    output VGA_SYNC_N,
    output VGA_BLANK_N,

    output [6:0] HEX5,
    output [6:0] HEX4,
    output [6:0] HEX3,
    output [6:0] HEX2,
    output [6:0] HEX1,
    output [6:0] HEX0,

    output [9:0] LED
);

    /* Global clock and reset lines                                           */
    /* ---------------------------------------------------------------------- */
    wire clock, reset_n;
    assign clock = CLOCK_50;
    assign reset_n = KEY[3];

    /* Button initialization                                                  */
    /* ---------------------------------------------------------------------- */
    wire [3:0] keypulse;

    Button buttons[3:0] 
    ( .clock(clock), .reset_n(reset_n), .gpio(KEY), .pulse(keypulse) );

    wire [31:0] count;
    Timer timer 
    ( 
        .clock(clock), 
        .reset_n(reset_n), 
        .threshold(32'd50000000), 
        .count(count) 
    );

    assign LED[9] = count < 32'd25000000;

    /* Seven-segment LED initialization                                       */
    /* ---------------------------------------------------------------------- */
    wire [41:0] seven_segment_leds;
    wire [23:0] seven_segment_hex;

    assign { HEX5, HEX4, HEX3, HEX2, HEX1, HEX0 } = seven_segment_leds;

    SevenSegmentDriver seven_segment_drivers[5:0]
    ( .hex_digit(seven_segment_hex), .hex_display(seven_segment_leds) );

    /* PS/2 keyboard initialization                                           */
    /* ---------------------------------------------------------------------- */
    wire [255:0] keytable;
    wire [7:0] keyevent;

    PS2Keyboard keyboard
    ( 
        .clock(clock), 
        .reset_n(reset_n), 

        .ps2_clock(PS2_CLK), 
        .ps2_data(PS2_DAT),

        .keytable_out(keytable),
        .keyevent_out(keyevent)
    );

    PS2KeyboardDisplay keyboard_display
    (
        .clock(clock),
        .reset_n(reset_n),
        .keyevent_in(keyevent),
        .seven_segment_hex(seven_segment_hex)
    );

    assign LED[8] = keytable[`SCANCODE_KEY_Q];
    assign LED[7] = keytable[`SCANCODE_KEY_W];
    assign LED[6] = keytable[`SCANCODE_KEY_E];
    assign LED[5] = keytable[`SCANCODE_KEY_R];
    assign LED[4] = keytable[`SCANCODE_KEY_T];
    assign LED[3] = keytable[`SCANCODE_KEY_Y];
    assign LED[2] = keytable[`SCANCODE_KEY_U];
    assign LED[1] = keytable[`SCANCODE_KEY_I];
    assign LED[0] = keytable[`SCANCODE_KEY_SPACE];

    /* Renderer, VRAM, and VGA initialization                                 */
    /* ---------------------------------------------------------------------- */
    wire [9:0] vram_rd_row, vram_rd_col;
    wire [23:0] vram_rd_data;

    MandelbrotComputer mandelbrot
    (
        .clock(clock),
        .reset_n(reset_n),

        .zoom_in(keytable[`SCANCODE_KEY_I]),
        .zoom_out(keytable[`SCANCODE_KEY_O]),

        .pan_up(keytable[`SCANCODE_KEY_W]),
        .pan_down(keytable[`SCANCODE_KEY_S]),
        .pan_left(keytable[`SCANCODE_KEY_A]),
        .pan_right(keytable[`SCANCODE_KEY_D]),

        .vga_row_in(vram_rd_row),
        .vga_col_in(vram_rd_col),
        .vram_out(vram_rd_data)
    );

    VGADisplay vga_display
    (
        .clock(clock),
        .reset_n(reset_n),

        .vram_rd_in(vram_rd_data),
        .vram_rd_row(vram_rd_row),
        .vram_rd_col(vram_rd_col),

        .vga_clock(VGA_CLK),
        .vga_sync_n(VGA_SYNC_N),
        .vga_blank_n(VGA_BLANK_N),

        .vga_hsync(VGA_HSYNC),
        .vga_vsync(VGA_VSYNC),

        .vga_red(VGA_RED),
        .vga_grn(VGA_GRN),
        .vga_blu(VGA_BLU)
    );

endmodule
