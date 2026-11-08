`timescale 1ns/1ns

import textfont::*;

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

	input 			 	term_ready,
	output reg [7:0]	term_out_char,
	output reg			term_write_en,

	// input reg [10:0] ps2_key
	input reg [7:0]	ascii_code,
	input logic		ascii_code_new,
	input logic 	ps2_toggle

);



// wire [8:0] 	scancode;
// wire		key_action;
// wire		key_toggle;

// assign scancode = ps2_key[8:0];
// assign key_action = ps2_key[9];
// assign key_toggle = ps2_key[10];

// reg [11:0] xpos = 10, ypos = 10;

// reg [5:0] i = 0,j = 0;

reg last_ps2_toggle = 1'b0;

always @(posedge clk) begin
    if (reset)
	begin
        // fb_offs   <= 32'd0;
        // init_video <= 1'b1;
        // DDRAM_WE  <= 1'b0;
    end
	else if (term_ready)
	begin
		if (ascii_code_new && ps2_toggle != last_ps2_toggle)
		begin
			term_out_char <= ascii_code;
			term_write_en <= 1'b1;
			last_ps2_toggle <= ps2_toggle;
		end
		else begin
			term_write_en <= 1'b0;
			last_ps2_toggle <= ps2_toggle;
		end
	end
	else if (!term_ready)
	begin
		term_write_en <= 1'b0;
	end

	// 	if (DDRAM_WE) begin
	// 		if (!DDRAM_BUSY) begin
	// 			DDRAM_WE <= 1'b0;
	// 			case(key_scancode) 
	// 				ARROW_RIGHT : xpos <= (xpos <= fb_width-1)? xpos + 1 : xpos;
	// 				ARROW_LEFT  : xpos <= (xpos > 0)? xpos - 1 : xpos;
	// 				ARROW_DOWN  : ypos <= (ypos <= fb_height-1)? ypos + 1 : ypos;
	// 				ARROW_UP    : ypos <= (ypos > 0)? ypos - 1 : ypos;	
	// 			endcase
	// 			key_scancode <= 9'd0;
	// 		end
	// 	end
	// 	else if (key_pressed) begin
	// 		setpixel(
	// 			xpos, ypos,
	// 			fb_width, fb_height, fb_stride,
	// 			8'hff, 8'hff, 8'hff,
	// 			DDRAM_DIN, fb_offs, DDRAM_BE
	// 		);

	// 		DDRAM_WE <= 1'b1;
	// 		key_pressed <= 1'b0;
	// 	end
	// 	else
	// 	begin
	// 		if (key_action) begin
	// 			if (key_released) begin
	// 				key_pressed <= 1'b1;
	// 				key_released <= 1'b0;
	// 				key_scancode <= scancode;
	// 			end
	// 		end
	// 		else
	// 		begin
	// 			key_released <= 1'b1;
	// 			key_pressed <= 1'b0;
	// 		end
	// 	end
end






endmodule
