module vga_controller(
	input  logic   vga_clock,
	input  logic   reset_n,
	output logic   sync_n,
	output logic   blank_n,
	output logic   hsync_n,
	output logic   vsync_n,
	output logic  [9:0] hcount,
	output logic  [9:0] vcount
);
	
	localparam N_WIDE_ALL=800, N_WIDE_V=640, N_WIDE_F=48, N_WIDE_S=96, N_WIDE_B=16;  //for hcounter
	localparam N_HIGH_ALL=525, N_HIGH_V=480, N_HIGH_F=33, N_HIGH_S=2 , N_HIGH_B=10;  //for vcounter
				  

	// hcounter
	always_ff@(posedge vga_clock, negedge reset_n) begin
		if (!reset_n) 
			hcount <= 'd0;
		else begin
			if (hcount == N_WIDE_ALL-'d1)
				hcount <= 'd0; 
			else
				hcount <= hcount + 'd1;
			end
		end
	
	// vcounter
	always_ff@(posedge vga_clock, negedge reset_n) begin
		if (!reset_n) 
			vcount <= 'd0;
		else begin
			if (hcount == N_WIDE_ALL-'d1) begin
				if (vcount == N_HIGH_ALL-'d1)
					vcount <= 'd0;
				else
					vcount <= vcount + 'd1;
				end
			else
				vcount <= vcount;
		end
	end
			
	// output logic for vsync_n, hsync_n, blank_n, sync_n
	// when hcount = [N_WIDE_V+N_WIDE_B, N_WIDE_V+N_WIDE_B+N_WIDE_S), reset hsync_n
	assign hsync_n = ((hcount >= N_WIDE_V+N_WIDE_B) && (hcount < N_WIDE_V+N_WIDE_B+N_WIDE_S)) ? '0 : '1;
	assign vsync_n = ((vcount >= N_HIGH_V+N_HIGH_B) && (vcount < N_HIGH_V+N_HIGH_B+N_HIGH_S)) ? '0 : '1;
	assign blank_n = ((hcount >= N_WIDE_V) || (vcount >= N_HIGH_V)) ? '0 : '1;
	assign sync_n = '0;

endmodule