`timescale 1ns/1ns

import textfont::*;


module hdterm
(
    input logic     clk,
    input logic     reset,

	input [31:0]    fb_base,
    input [11:0]    fb_width,
    input [11:0]    fb_height,
    input [13:0]    fb_stride,
 
    input [7:0]     character,
    input logic     write_en,
    output reg      term_ready,

	input		        DDRAM_BUSY,		    // We need to wait
	output [7:0]        DDRAM_BURSTCNT,     // always 1
	output [28:0]       DDRAM_ADDR,		    // we send the ddr address to sys
	output reg [63:0]   DDRAM_DIN,		    // data to store in ddr memory
	output reg [7:0]    DDRAM_BE,			// byte enable bits (8x8 = 64 bit)
	output reg          DDRAM_WE			// we want to write to ddr memory
);

reg [7:0]   fifo_chars [7:0];
reg [2:0]   fifo_wptr, fifo_rptr;
reg         fifo_overflow;
reg         fifo_empty;
reg         fifo_full;
reg [7:0]   fifo_char;

assign fifo_empty = fifo_rptr == fifo_wptr;
assign fifo_full = fifo_wptr + 3'd1 == fifo_rptr;

assign fifo_char = fifo_chars[fifo_rptr];

reg		init_term = 1'b0;
reg [31:0] fb_offs = 32'd0;

wire [31:0] ram_address;

assign ram_address = fb_base + fb_offs;
assign term_ready = !init_term && !fifo_full;

// assign DDRAM_ADDR = ram_address[31:3];

assign DDRAM_ADDR = {3'b001, ram_address[28:3]};

assign DDRAM_BURSTCNT = 8'd1;

wire [25:0] bytes_per_screen;
assign bytes_per_screen = fb_stride * fb_height;


reg [11:0] xpos;
reg [11:0] ypos;


reg [2:0]   i = 0;
reg [3:0]   j = 0;

always_ff @(posedge clk)
begin
    if (reset) begin
        xpos <= 12'd0;
        ypos <= 12'd16;
        fifo_rptr <= 3'd0;
        fifo_wptr <= 3'd0;
        fifo_overflow <= 1'b0;
        init_term <= 1'b1;
        fb_offs   <= 32'd0;
        DDRAM_WE  <= 1'b0;
    end
    else if (init_term)
    begin
        if (!DDRAM_WE)
        begin
            DDRAM_DIN <= 64'hFF802040_FF802040; // 64'hFFFF4080_FFFF4080;	// ABGR
            DDRAM_BE  <= 8'b1111_1111;
            DDRAM_WE  <= 1'b1;
        end
        else if (!DDRAM_BUSY)
        begin
            if (fb_offs + 32'd8 < bytes_per_screen) begin
                fb_offs <= fb_offs + 32'd8;
            end
            else begin
                init_term <= 1'b0;
                DDRAM_WE   <= 1'b0;
				fb_offs <= 32'd0;
            end
        end        
    end
    else if (!DDRAM_WE)     // else: init_term is done.
    begin
        if (write_en)
        begin
            if (!fifo_full)
            begin
                fifo_chars[fifo_wptr] <= character;
                fifo_wptr <= fifo_wptr + 3'd1;            
            end
            else begin
                fifo_overflow <= 1'b1;
            end
        end
        else if (!fifo_empty )
        begin
            if (fifo_char == 8'd10 || fifo_char == 8'd13)
            begin
                fifo_rptr <= fifo_rptr + 1'b1;

                if (fifo_char == 8'd13)
                    xpos <= 0;

                if (fifo_char == 8'd10) begin
                    xpos <= 0;
                    if (ypos + 16 < fb_height)
                        ypos <= ypos + 16;
                end
            end
            else begin
                drawchar(xpos, ypos, fifo_char[6:0],
                    fb_width, fb_height, fb_stride,
                    8'hff, 8'hff, 8'hff,  i, j,
                    DDRAM_DIN, fb_offs, DDRAM_BE);

 			    DDRAM_WE <= 1'b1;
		    end	
        end	
    end
    else if (DDRAM_WE)
    begin
		if (!DDRAM_BUSY)
        begin
            DDRAM_WE <= 1'b0;   // stop writing to DDRAM, prepare for next pixel
            
            if (i == 7) begin
                i <= 3'h0;
                if (j == 15) begin
                    xpos <= ((xpos + 12'd8) < fb_width)? xpos + 12'd8 : 12'd0;
                    ypos <= ((xpos + 12'd8) < fb_width)? ypos : ((ypos + 12'd16) < fb_height)? ypos + 12'd16 : ypos;
                
                    fifo_rptr <= fifo_rptr + 3'd1;
                    i <= 3'h0;
                    j <= 4'h0;
                end
                else
                begin
                    j <= j + 4'd1;
                end
            end
            else
            begin
                i <= i + 3'd1; 
            end
        end
    end        
end   


endmodule
