/*
 * top.sv - Platformer STARTER. Pure wiring, one clock domain.
 *   ARROW KEYS on a PS/2 keyboard: LEFT / RIGHT = run, UP = jump.
 *   Board buttons still work too:  KEY1 left, KEY0 right, KEY3 jump.
 *   SW9 up = reset.
 *
 * Note on buttons: running must respond to HELD keys, so left/right are
 * level signals (just synchronized). Jump fires on the PRESS edge - the
 * course's keypress module fires on release, which feels laggy for jumping.
 */
module top(
	input  logic        CLOCK_50,
	input  logic  [3:0] KEY,
	input  logic  [9:0] SW,
	input  logic        PS2_CLK,     // PS/2 keyboard (arrow keys)
	input  logic        PS2_DAT,
	output logic        VGA_CLK,
	output logic        VGA_HS,
	output logic        VGA_VS,
	output logic        VGA_BLANK_N,
	output logic        VGA_SYNC_N,
	output logic  [7:0] VGA_R,
	output logic  [7:0] VGA_G,
	output logic  [7:0] VGA_B
);
	logic reset_n;
	assign reset_n = ~SW[9];

	logic vga_clk;
	clock_generator u_pll (.refclk(CLOCK_50), .rst(!reset_n), .outclk_0(vga_clk));
	assign VGA_CLK = vga_clk;

	logic [9:0] hcount, vcount;
	vga_controller u_vga (
		.vga_clock(vga_clk), .reset_n(reset_n),
		.sync_n(VGA_SYNC_N), .blank_n(VGA_BLANK_N),
		.hsync_n(VGA_HS),    .vsync_n(VGA_VS),
		.hcount(hcount),     .vcount(vcount)
	);

	// synchronize the raw (active-low) keys into the pixel-clock domain
	logic [3:0] key_s1, key_s2, key_s3;
	always_ff @(posedge vga_clk) begin
		key_s1 <= KEY;  key_s2 <= key_s1;  key_s3 <= key_s2;
	end

	// PS/2 keyboard: arrow keys (a GIVEN module, like keypress)
	logic kb_left, kb_right, kb_down, kb_jump;
	ps2_arrows u_kb (
		.clock(vga_clk), .reset_n(reset_n),
		.ps2_clk(PS2_CLK), .ps2_dat(PS2_DAT),
		.left_held(kb_left), .right_held(kb_right),
		.down_held(kb_down), .up_pulse(kb_jump)
	);

	// either input device works: keyboard OR board buttons
	logic move_left, move_right, jump_press;
	assign move_left  = kb_left  ;
	assign move_right = kb_right  ;
	assign jump_press = kb_jump  ;
	
	logic rmove_left, rmove_right, rjump_press;

	assign rmove_left = ~key_s2[3];
	assign rmove_right= ~key_s2[1] ;
	assign rjump_press= ~key_s2[2];

	pattern_generator u_game (
		.vga_clock(vga_clk), .reset_n(reset_n),
		.move_left(move_left), .move_right(move_right), .jump(jump_press), .rmove_left(rmove_left), .rmove_right(rmove_right), .rjump_press(rjump_press),
		.hcount(hcount), .vcount(vcount),
		.red(VGA_R), .green(VGA_G), .blue(VGA_B)
	);
endmodule