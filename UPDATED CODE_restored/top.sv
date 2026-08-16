module top(
	input  logic   clock,
	input  logic   reset_n,
	output logic   sync_n,
	output logic   blank_n,
	output logic   hsync_n,
	output logic   vsync_n,
	output logic   vga_clk,
	output logic  [7:0] red,
	output logic  [7:0] green,
	output logic  [7:0] blue
);
	
	
	logic [9:0] hcount, vcount;
	
	//25.175MHz
	clock_generator vga_clock(
			.refclk(clock),      //  refclk.clk
			.rst(!reset_n),      //   reset.reset
			.outclk_0(vga_clk)   // outclk0.clk
	);
	
	vga_controller ctr1(
		.vga_clock(vga_clk),
		.reset_n(reset_n),
		.sync_n(sync_n),
		.blank_n(blank_n),
		.hsync_n(hsync_n),
		.vsync_n(vsync_n),
		.hcount(hcount),
		.vcount(vcount)
	);



assign {red, green, blue} = {8'hff, 8'h00, 8'h00};


endmodule
