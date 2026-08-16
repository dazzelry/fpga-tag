/*
 * ps2_arrows.sv - PS/2 keyboard receiver for the platformer  (GIVEN module)
 *
 * Listens to a PS/2 keyboard and tracks the four ARROW KEYS:
 *   left_held / right_held / down_held : high while the key is held
 *   up_pulse                           : one clock pulse per UP press (= jump)
 *
 * How a PS/2 keyboard talks (the 30-second version):
 *   - The KEYBOARD drives its own slow clock (~10-15 kHz). One bit of data
 *     arrives on every FALLING edge of that clock.
 *   - 11 clocks = one byte: start(0), 8 data bits (LSB first), parity, stop(1).
 *   - Press a key   -> it sends the key's "make" code   (arrows: E0 xx)
 *     Release a key -> it sends F0 then the same code   (arrows: E0 F0 xx)
 *   So "held" is just: set a flag on make, clear it when F0 came right before.
 *
 * We simply ignore the E0 prefix byte - a bonus: the numpad arrows (8/4/6/2,
 * NumLock off) share the same base codes, so they work too.
 */

module ps2_arrows(
	input  logic clock,          // the 25 MHz pixel clock
	input  logic reset_n,
	input  logic ps2_clk,        // from the keyboard (async, slow)
	input  logic ps2_dat,
	output logic left_held,
	output logic right_held,
	output logic down_held,
	output logic up_pulse        // one pulse per press of UP
);

	// arrow-key scan codes (the byte after the E0 prefix)
	localparam [7:0] CODE_UP    = 8'h75;
	localparam [7:0] CODE_LEFT  = 8'h6B;
	localparam [7:0] CODE_RIGHT = 8'h74;
	localparam [7:0] CODE_DOWN  = 8'h72;
	localparam [7:0] CODE_BREAK = 8'hF0;   // "the next code is a release"

	// ---- synchronize the two async keyboard wires into our clock domain ----
	logic clk_s1, clk_s2, clk_s3, dat_s1, dat_s2;
	always_ff @(posedge clock) begin
		clk_s1 <= ps2_clk;  clk_s2 <= clk_s1;  clk_s3 <= clk_s2;
		dat_s1 <= ps2_dat;  dat_s2 <= dat_s1;
	end
	logic ps2_falling;
	assign ps2_falling = clk_s3 & ~clk_s2;      // keyboard clock: 1 -> 0

	// ---- collect 11 bits into one byte ----
	logic [3:0]  bit_cnt;
	logic [10:0] shreg;
	logic [7:0]  rx_byte;
	logic        byte_ready;
	logic [15:0] idle_cnt;                      // watchdog: resync if half-a-frame stalls

	always_ff @(posedge clock, negedge reset_n) begin
		if (!reset_n) begin
			bit_cnt <= '0;  shreg <= '0;
			rx_byte <= '0;  byte_ready <= 1'b0;  idle_cnt <= '0;
		end else begin
			byte_ready <= 1'b0;
			if (ps2_falling) begin
				idle_cnt <= '0;
				shreg    <= {dat_s2, shreg[10:1]};      // bits arrive LSB first
				if (bit_cnt == 4'd10) begin
					bit_cnt    <= '0;
					rx_byte    <= shreg[9:2];           // the 8 data bits
					byte_ready <= 1'b1;
				end else
					bit_cnt <= bit_cnt + 4'd1;
			end
			else if (bit_cnt != 0) begin
				// no keyboard edge for ~2.6 ms mid-byte? we lost sync - start over
				if (idle_cnt == '1) begin bit_cnt <= '0; idle_cnt <= '0; end
				else idle_cnt <= idle_cnt + 16'd1;
			end
		end
	end

	// ---- decode: make sets a key's flag, F0+make clears it ----
	logic releasing;                            // "we just saw F0"
	logic up_held, up_prev;

	always_ff @(posedge clock, negedge reset_n) begin
		if (!reset_n) begin
			releasing <= 1'b0;
			up_held <= 1'b0;  left_held <= 1'b0;
			right_held <= 1'b0;  down_held <= 1'b0;
		end else if (byte_ready) begin
			if (rx_byte == CODE_BREAK)
				releasing <= 1'b1;
			else begin
				case (rx_byte)
					CODE_UP:    up_held    <= ~releasing;
					CODE_LEFT:  left_held  <= ~releasing;
					CODE_RIGHT: right_held <= ~releasing;
					CODE_DOWN:  down_held  <= ~releasing;
					default: ;                  // E0 and everything else: ignore
				endcase
				releasing <= 1'b0;
			end
		end
	end

	// jump wants one pulse per press, not a level
	always_ff @(posedge clock) up_prev <= up_held;
	assign up_pulse = up_held & ~up_prev;

endmodule

