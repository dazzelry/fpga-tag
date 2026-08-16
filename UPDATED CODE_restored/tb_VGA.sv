`timescale 1ns/1ns
module tb_VGA;
	logic   clock, reset_n;
	logic   sync_n, blank_n, hsync_n, vsync_n, vga_clk;
	logic  [7:0] red, green, blue;
	
	top dut(clock,reset_n,sync_n,blank_n,hsync_n,vsync_n,vga_clk,red,green,blue);
	
	
	initial begin
		clock = '0;
		while (1) begin
			#5ns clock <= ~clock;
			end
		end
	
	initial begin
		reset_n = '0;
		# 100ns;
		reset_n = '1;
		end

endmodule
		