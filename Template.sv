//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================
`timescale 1ns/1ns
module emu
(
//	`include "sys/emu_ports.vh"

	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

	input   [5:0] LFB_FMT,
	input  [31:0] LFB_BASE,
	input  [11:0] LFB_WIDTH,
	input  [11:0] LFB_HEIGHT,
	input  [13:0] LFB_STRIDE,

	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS

);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
// assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

parameter DisplayWidth = 12'd1280;
parameter DisplayHeight_PAL = 12'd720;
parameter DisplayHeight_NTSC = 12'd720;

// From PSX
assign FB_BASE    = 32'h30_0_00_00_0;
assign FB_EN      = 1'b1;

assign FB_WIDTH   = DisplayWidth;
assign FB_HEIGHT  = status[2] ? DisplayHeight_PAL : DisplayHeight_NTSC;
assign FB_STRIDE  =  4*DisplayWidth; // 4* 529  // 14'd2048;
assign FB_FORCE_BLANK = 0;

// FB_FORMAT:
//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
//    [3]   : 0=16bits 565 1=16bits 1555
//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
//
assign FB_FORMAT  = 5'b00110;
// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)


//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6          7         8         9
// 01234567890123456789012345678901 23456789012345678901234567890123 45678901234567890123456789012345
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV


`include "build_id.v" 
localparam CONF_STR = {
	"Template;;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O[2],TV Mode,NTSC,PAL;",
	"O[4:3],Noise,White,Red,Green,Blue;",
	"-;",
	"P1,Test Page 1;",
	"P1-;",
	"P1-, -= Options in page 1 =-;",
	"P1-;",
	"P1O[5],Option 1-1,Off,On;",
	"d0P1F1,BIN;",
	"H0P1O[10],Option 1-2,Off,On;",
	"-;",
	"P2,Test Page 2;",
	"P2-;",
	"P2-, -= Options in page 2 =-;",
	"P2-;",
	"P2S0,DSK;",
	"P2O[7:6],Option 2,1,2,3,4;",
	"-;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"v,0;", // [optional] config version 0-99. 
	        // If CONF_STR options are changed in incompatible way, then change version number too,
			  // so all options will get default values on first start.
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),
	
	.ps2_key(ps2_key)
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys)
);

wire reset = RESET | status[0] | buttons[1];

wire [1:0] col = status[4:3];

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire hvcnt_atzero;
wire [7:0] video;

// Leave H/V sync always on. This stabilizes the video output while the core
// is in reset. This example releases the reset when H/V counters are at zero.
reg reset_core = 1;
always @(posedge clk_sys) begin
	if(reset) reset_core <= 1;
	else reset_core <= 0; // if(hvcnt_atzero) reset_core <= 0;
end

assign DDRAM_CLK = clk_sys;


logic [7:0] char2print;
logic		do_print;
logic		term_ready;

hdterm terminal(
	.clk (clk_sys),
	.reset(reset_core),

	.fb_base(FB_BASE),
	.fb_width(FB_WIDTH),
	.fb_height(FB_HEIGHT),
	.fb_stride(FB_STRIDE),
	
	.character(char2print),
	.write_en(do_print),
	.term_ready(term_ready),

  	.DDRAM_BUSY      (DDRAM_BUSY      ),
    .DDRAM_BURSTCNT  (DDRAM_BURSTCNT  ),
    .DDRAM_ADDR      (DDRAM_ADDR      ),
    .DDRAM_DIN       (DDRAM_DIN       ),
    .DDRAM_BE        (DDRAM_BE        ),
    .DDRAM_WE        (DDRAM_WE        )
);

reg [7:0]	ascii_code;
logic 		ascii_ready;
logic 		ps2_toggle;

simple_keys simple_keys (
	.reset       (reset),
	.ps2_key     (ps2_key),
	// .ps2_scancode(ps2_scancode),
	// .ps2_ready   (ps2_ready),
	.ascii_code  (ascii_code),
	.ascii_ready (ascii_ready),
	.ps2_toggle  (ps2_toggle),
	// .arrow_left  (arrow_left),
	// .arrow_right (arrow_right),
	// .arrow_up    (arrow_up),
	// .arrow_down  (arrow_down)
);

mycore mycore
(
	.clk(clk_sys),
	.reset(reset_core),


	// .fb_base(FB_BASE),
	// .fb_width(FB_WIDTH),
	// .fb_height(FB_HEIGHT),
	// .fb_stride(FB_STRIDE),
	// .fb_vbl(FB_VBL),
	// .fb_ll(FB_LL),

   // vram/ddr3 (from PSX)
//    .DDRAM_BUSY      (DDRAM_BUSY      ),
//    .DDRAM_BURSTCNT  (DDRAM_BURSTCNT  ),
//    .DDRAM_ADDR      (DDRAM_ADDR      ),
//    .DDRAM_DOUT      (DDRAM_DOUT      ),
//    .DDRAM_DOUT_READY(DDRAM_DOUT_READY),
//    .DDRAM_RD        (DDRAM_RD        ),
//    .DDRAM_DIN       (DDRAM_DIN       ),
//    .DDRAM_BE        (DDRAM_BE        ),
//    .DDRAM_WE        (DDRAM_WE        ),

//    .ps2_key         (ps2_key),
	.ascii_code		(ascii_code),
	.ascii_code_new (ascii_ready),
	.ps2_toggle  	(ps2_toggle),
	.term_ready    	(term_ready),
	.term_out_char 	(char2print),
	.term_write_en 	(do_print)

);

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = ce_pix;


// assign CLK_VIDEO = 1'b0; //  clk_sys;
// assign CE_PIXEL = 1'b0;  // ce_pix;

// assign VGA_DE = 1'b0; // ~(HBlank | VBlank);
// assign VGA_HS = 1'b0; // HSync;
// assign VGA_VS = 1'b0; // VSync;
// assign VGA_G  = 8'd0; // (!col || col == 2) ? video : 8'd0;
// assign VGA_R  = 8'd0; // (!col || col == 1) ? video : 8'd0;
// assign VGA_B  = 8'd0; // (!col || col == 3) ? video : 8'd0;

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER    = act_cnt[26]  ? act_cnt[25:18]  > act_cnt[7:0]  : act_cnt[25:18]  <= act_cnt[7:0];

endmodule
