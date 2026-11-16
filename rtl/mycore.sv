`timescale 1ns/1ns

task setpixel;
	input		[11:0]	xpos;
	input		[11:0]	ypos;
	input		[11:0]	fb_width;
	input		[11:0]	fb_height;
	input		[13:0]	fb_stride;
	input		[7:0]	r, g, b;

	output reg	[63:0]	pixel64;
	output reg	[31:0]	fb_offs;
	output reg	[7:0]	fb_be;

	reg 		[11:0]	x, y;
	reg 		[31:0]	raw_offs;

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
	input				clk,
	input				reset,

	output reg 	[26:0]	sdram_addr,
	input		[31:0]	sdram_dout,	// 32-bit data output to cpu
	output reg	[31:0]	sdram_din,	// 32-bit data input from cpu to ram
	output reg			sdram_we,
	output reg			sdram_rd,
	input				sdram_ready,


	output				hvcnt_atzero,

	input 			 	term_ready,
	output reg	[7:0]	term_out_char,
	output reg			term_write_en,

	// input reg [10:0] ps2_key
	input reg	[7:0]	ascii_code,
	input logic			ascii_code_new,
	input logic 		ps2_toggle

);


reg last_ps2_toggle = 1'b0;

logic meminit_started = 1'b0;
logic meminit_done = 1'b0;

typedef enum logic [3:0] {INIT, WRITE1, WAIT_W1, WRITE2, WAIT_W2, READ1, WAIT_R1, READ2, WAIT_R2, DONE} initstate_t;

initstate_t initstate;


parameter		test_addr = 27'h1000;		// MUST BE EVEN ADDRESS DUE TO WORD ALIGNMENT
parameter		test_val1 = 32'h1337DEAD;
parameter		test_val2 = 32'h2337BEAD;

reg		[31:0]	test_read1 = 32'd0;
reg		[31:0]	test_read2 = 32'd0;

logic write_validated1;
logic write_validated2;

always_comb
begin
	write_validated1 = test_read1 == test_val1;
	write_validated2 = test_read2 == test_val2;
end

always @(posedge clk) begin
	if (reset)
	begin
		meminit_started <= 1'b0;
		meminit_done <= 1'b0;
		sdram_we	<= 1'b0;
		sdram_rd	<= 1'b0;

		initstate <= WRITE1;
	end
	else if (!meminit_done)
	begin
		case(initstate)
			WRITE1: begin
				if (sdram_ready) begin
					sdram_addr	<= test_addr;
					sdram_din	<= test_val1;
					sdram_we	<= 1'b1;

					initstate	<= WAIT_W1;					
				end
			end
			WAIT_W1: begin
				sdram_we <= 1'b0;

				initstate <= WRITE2;
			end
			WRITE2: begin
				if (sdram_ready) begin
					sdram_addr	<= sdram_addr + 27'd4;
					sdram_din	<= test_val2;
					sdram_we	<= 1'b1;

					initstate	<= WAIT_W2;		
				end
			end
			WAIT_W2: begin
				if (sdram_ready) begin
					sdram_we <= 1'b0;

					initstate <= READ1;
				end
			end
			READ1: begin
				if (sdram_ready) begin
					sdram_addr	<= test_addr;
					sdram_rd	<= 1'b1;

					initstate	<= WAIT_R1;
				end
			end
			WAIT_R1: begin
				if (sdram_ready) begin
					test_read1	<= sdram_dout;
					sdram_rd <= 1'b0;

					initstate	<= READ2;
				end
			end
			READ2: begin
				if (sdram_ready) begin
					sdram_addr	<= sdram_addr + 27'd4;
					sdram_rd	<= 1'b1;

					initstate	<= WAIT_R2;	
				end			
			end
			WAIT_R2: begin
				if (sdram_ready) begin
					test_read2	<= sdram_dout;
					sdram_rd	<= 1'b0;

					initstate	<= DONE;
				end				
			end
			DONE: begin
				if (write_validated1 && write_validated2) begin
					meminit_done <= 1'b1;				
				end
			end
			default: begin
				meminit_done <=1'b1;
			end
		endcase
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
end

endmodule
