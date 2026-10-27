`timescale 1ns/1ns

parameter ARROW_UP    = 9'h175;
parameter ARROW_DOWN  = 9'h172;
parameter ARROW_LEFT  = 9'h16b;
parameter ARROW_RIGHT = 9'h174;

task setpixel;
    input [11:0] xpos;
    input [11:0] ypos;
    input [11:0] fb_width;
    input [11:0] fb_height;
    input [13:0] fb_stride;
    input [7:0]  r, g, b;

    output reg [63:0] pixel64;
    output reg [31:0] fb_offs;
    output reg [7:0]  fb_be;

    reg [11:0] x, y;
    reg [31:0] raw_offs;

    begin
        x = (xpos < fb_width) ? xpos : fb_width - 1'b1;
        y = (ypos < fb_height) ? ypos : fb_height - 1'b1;

        raw_offs = ({20'd0, y} * {18'd0, fb_stride}) + ({20'd0, x} << 2);

        pixel64 <= {8'hff, b, g, r, 8'hff, b, g, r};
        fb_be   <= raw_offs[2] ? 8'b1111_0000 : 8'b0000_1111;
        fb_offs <= {raw_offs[31:3], 3'b000};
    end
endtask



module mycore
(
	input         clk,
	input         reset,
	
	output        hvcnt_atzero,

	input [31:0]  fb_base,
	input [11:0]  fb_width,
	input [11:0]  fb_height,
	input [13:0]  fb_stride,
	input         fb_vbl,
	input         fb_ll,

	input		  DDRAM_BUSY,		// We need to wait
	output [7:0]  DDRAM_BURSTCNT,	// always 1
	output [28:0] DDRAM_ADDR,		// we send the ddr address to sys
	input  [63:0] DDRAM_DOUT,		// data read from ddr memory
	input         DDRAM_DOUT_READY,	// sys tells us when ddr data is ready
	output        DDRAM_RD,			// we want to read from ddr memory
	output reg [63:0] DDRAM_DIN,		// data to store in ddr memory
	output reg [7:0] DDRAM_BE,			// byte enable bits (8x8 = 64 bit)
	output reg       DDRAM_WE,			// we want to write to ddr memory

	input reg [10:0] ps2_key

);


reg [31:0] fb_offs = 32'd0;

wire [31:0] ram_address;

assign ram_address = fb_base + fb_offs;


// assign DDRAM_ADDR = ram_address[31:3];

assign DDRAM_ADDR = {3'b001, ram_address[28:3]};

assign DDRAM_BURSTCNT = 8'd1;

assign DDRAM_RD = 1'b0;

assign hvcnt_atzero = fb_vbl;

wire [25:0] bytes_per_screen;

assign bytes_per_screen = fb_stride * fb_height;

reg		init_video = 1'b0;

reg    key_pressed = 1'b0;

reg			key_released = 1'b1;
reg [8:0]	key_scancode = 9'd0;

wire [8:0] 	scancode;
wire		key_action;
wire		key_toggle;

assign scancode = ps2_key[8:0];
assign key_action = ps2_key[9];
assign key_toggle = ps2_key[10];

// assign key_pressed = KEYBOARD[10];

reg [11:0] xpos = 10, ypos = 10;

always @(posedge clk) begin
    if (reset) begin
        fb_offs   <= 32'd0;
        init_video <= 1'b1;
        DDRAM_WE  <= 1'b0;
    end
    else if (init_video) begin
        if (!DDRAM_WE) begin
            DDRAM_DIN <= 64'hFF802040_FF802040; // 64'hFFFF4080_FFFF4080;	// ABGR
            DDRAM_BE  <= 8'b1111_1111;
            DDRAM_WE  <= 1'b1;
        end
        else if (!DDRAM_BUSY) begin
            if (fb_offs + 32'd8 < bytes_per_screen) begin
                fb_offs <= fb_offs + 32'd8;
            end
            else begin
                init_video <= 1'b0;
                DDRAM_WE   <= 1'b0;
				fb_offs <= 32'd0;
            end
        end
    end
	else begin
		if (DDRAM_WE) begin
			if (!DDRAM_BUSY) begin
				DDRAM_WE <= 1'b0;
				case(key_scancode) 
					ARROW_RIGHT : xpos <= (xpos <= fb_width-1)? xpos + 1 : xpos;
					ARROW_LEFT  : xpos <= (xpos > 0)? xpos - 1 : xpos;
					ARROW_DOWN  : ypos <= (ypos <= fb_height-1)? ypos + 1 : ypos;
					ARROW_UP    : ypos <= (ypos > 0)? ypos - 1 : ypos;	
				endcase
				key_scancode <= 9'd0;
			end
		end
		else if (key_pressed) begin
			setpixel(
				xpos, ypos,
				fb_width, fb_height, fb_stride,
				8'hff, 8'hff, 8'hff,
				DDRAM_DIN, fb_offs, DDRAM_BE
			);

			DDRAM_WE <= 1'b1;
			key_pressed <= 1'b0;
		end
		else
		begin
			if (key_action) begin
				if (key_released) begin
					key_pressed <= 1'b1;
					key_released <= 1'b0;
					key_scancode <= scancode;
				end
			end
			else
			begin
				key_released <= 1'b1;
				key_pressed <= 1'b0;
			end
		end
	end
end






endmodule
