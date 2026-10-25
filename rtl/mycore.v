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
	output reg       DDRAM_WE			// we want to write to ddr memory

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

always @(posedge clk) begin
    if (reset) begin
        fb_offs   <= 32'd0;
        init_video <= 1'b1;
        DDRAM_WE  <= 1'b0;
    end
    else if (init_video) begin
        if (!DDRAM_WE) begin
            // Present the first write request.
            // Do not advance the address yet.
            DDRAM_DIN <= 64'hFFFF4080_FFFF4080;	// ABGR
            DDRAM_BE  <= 8'b1111_1111;
            DDRAM_WE  <= 1'b1;
        end
        else if (!DDRAM_BUSY) begin
            // The current write has been accepted.
            if (fb_offs + 32'd8 < bytes_per_screen) begin
                fb_offs <= fb_offs + 32'd8;
                // Keep DDRAM_WE asserted for the next write.
            end
            else begin
                // The final write has been accepted.
                init_video <= 1'b0;
                DDRAM_WE   <= 1'b0;
            end
        end
        // If busy, hold the request, address and data unchanged.
    end
    else begin
        DDRAM_WE <= 1'b0;
    end
end

endmodule
