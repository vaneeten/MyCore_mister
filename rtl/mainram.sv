/*
 * 32 bit SDRAM bridge for 16 bit SDRAM controller
 */

module mainram(
	input				reset,			// reset to initialize RAM
	input				clk_sdram,		// clock ~100MHz
										//
										// SDRAM_* - signals to the MT48LC16M16 chip
	inout		[15:0]	SDRAM_DQ,		 // 16 bit bidirectional data bus
	output reg	[12:0]	SDRAM_A,		// 13 bit multiplexed address bus
	output reg			SDRAM_DQML,	 // two byte masks
	output reg			SDRAM_DQMH,	 // 
	output reg	[1:0]	SDRAM_BA,		 // two banks
	output				SDRAM_nCS,		// a single chip select
	output				SDRAM_nWE,		// write enable
	output				SDRAM_nRAS,	 // row address select
	output				SDRAM_nCAS,	 // columns address select
	output				SDRAM_CLK,
	output				SDRAM_CKE,		// clock enable
	input		[26:0]	sdram_addr,	 // 27 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
	output reg	[31:0]	sdram_dout32,	 // 32-bit data output to cpu, available when sdram_ready is high
	input		[31:0]	sdram_din32,	// 32-bit data input from cpu must be kept steady until sdram_ready is high
	input				sdram_we,		 // cpu requests write
	input				sdram_rd,		 // cpu requests read
	output reg			sdram_ready	 // dout is valid. Ready to accept new 32 bit read/write.

);

reg 	[26:0]	sdram_addr_latched;
reg 	[31:0]	data_latched;
reg 	[26:0]	sdram_addr16;
logic			sdram_ready16;
logic			sdram_we16;
logic			sdram_rd16;
reg		[15:0]	sdram_din16;		 // 16 bit data from cpu to sdram
reg		[15:0]	sdram_dout16;		// 16 bit data from sdram to cpu

typedef enum logic [3:0] { INIT_R_OR_W, WRITE_HIGH, INIT_W_LOW, WRITE_LOW, READ_HIGH, INIT_R_LOW, READ_LOW } state_t;

state_t state;

logic sdram_we_old;
logic sdram_rd_old;

wire sdram_we_rise = sdram_we & ~sdram_we_old;
wire sdram_rd_rise = sdram_rd & ~sdram_rd_old;

always_ff @(posedge clk_sdram) begin
    if (reset) begin
        sdram_we_old <= 1'b0;
        sdram_rd_old <= 1'b0;
    end
    else begin
        sdram_we_old <= sdram_we;
        sdram_rd_old <= sdram_rd;
    end
end

always_comb begin
	sdram_we16	 = 1'b0;
	sdram_rd16	 = 1'b0;
	sdram_addr16 = sdram_addr_latched;
	sdram_din16	= 16'b0;

	case (state)
		INIT_R_OR_W: begin
			if (sdram_ready16 && sdram_we_rise)
			begin
				sdram_we16   = 1'b1;
				sdram_addr16 = sdram_addr;
				sdram_din16  = sdram_din32[31:16];
			end
			else if (sdram_ready16 && sdram_rd_rise)
			begin
				sdram_rd16   = 1'b1;
				sdram_addr16 = sdram_addr;
			end
		end
		WRITE_HIGH: begin
			sdram_we16	 = 1'b0;
			sdram_addr16 = sdram_addr_latched;
			sdram_din16	= data_latched[31:16];
		end

		INIT_W_LOW: begin
			sdram_we16 = 1'b1;
			sdram_din16	= data_latched[15:0];
			sdram_addr16 = sdram_addr_latched + 2;
		end

		WRITE_LOW: begin
			sdram_we16	 = 1'b0;
			sdram_din16	= data_latched[15:0];
			sdram_addr16 = sdram_addr_latched + 2;
		end

		READ_HIGH: begin
			sdram_rd16	 = 1'b0;
			sdram_addr16 = sdram_addr_latched;
		end

		INIT_R_LOW: begin
			sdram_rd16 = 1'b1;
			sdram_addr16 = sdram_addr_latched + 2;
		end

		READ_LOW: begin
			sdram_rd16	 = 1'b0;
			sdram_addr16 = sdram_addr_latched + 2;
		end

		default: begin
		end

	endcase
end

always_comb begin
	sdram_ready = (state == INIT_R_OR_W) && sdram_ready16;
end

always_ff @(posedge clk_sdram) begin
	if (reset)
	begin
		state			 	<= INIT_R_OR_W;
		data_latched		<= 32'd0;
		sdram_addr_latched	<= 27'd0;
		sdram_dout32		<= 32'd0;
	end
	else 
	begin
		case (state)
			INIT_R_OR_W: begin
				if (sdram_ready16 && sdram_we_rise) begin
					data_latched <= sdram_din32;
					sdram_addr_latched <= sdram_addr;
					state <= WRITE_HIGH;
				end
				else if (sdram_ready16 && sdram_rd_rise) begin
					sdram_addr_latched <= sdram_addr;
					state <= READ_HIGH;
				end
			end

			WRITE_HIGH: begin
				if (sdram_ready16)
					state <= INIT_W_LOW;
			end

			INIT_W_LOW: begin
				state <= WRITE_LOW;
			end

			WRITE_LOW: begin
				if (sdram_ready16) begin
					state <= INIT_R_OR_W;
				end
			end

			READ_HIGH: begin
				if (sdram_ready16) begin
					sdram_dout32[31:16] <= sdram_dout16;
					state <= INIT_R_LOW;
				end
			end

			INIT_R_LOW: begin
				state <= READ_LOW;
			end

			READ_LOW: begin
				if (sdram_ready16) begin
					sdram_dout32[15:0] <= sdram_dout16;
					state <= INIT_R_OR_W;
				end
			end
		endcase
	end
end

sdram mainram (
	.init		(reset),
	.clk		(clk_sdram),
	.SDRAM_DQ	(SDRAM_DQ),
	.SDRAM_A	(SDRAM_A),
	.SDRAM_DQML	(SDRAM_DQML),
	.SDRAM_DQMH	(SDRAM_DQMH),
	.SDRAM_BA	(SDRAM_BA),
	.SDRAM_nCS	(SDRAM_nCS),
	.SDRAM_nWE	(SDRAM_nWE),
	.SDRAM_nRAS	(SDRAM_nRAS),
	.SDRAM_nCAS	(SDRAM_nCAS),
	.SDRAM_CLK	(SDRAM_CLK),
	.SDRAM_CKE	(SDRAM_CKE),
	.wtbt		(2'b11),		// 16bit mode:	bit1 - write high byte, bit0 - write low byte,	
								// 8bit mode:	2'b00 - use addr[0] to decide which byte to write
								// Ignored while reading.										 
	.addr		(sdram_addr16),
	.dout		(sdram_dout16),
	.din		(sdram_din16),
	.we			(sdram_we16),
	.rd			(sdram_rd16),
	.ready		(sdram_ready16)
);

endmodule
