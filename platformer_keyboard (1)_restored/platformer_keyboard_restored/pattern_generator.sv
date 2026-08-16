module pattern_generator(
    input  logic        vga_clock,
    input  logic        reset_n,
    input  logic        move_left,     // Keyboard Blue Player
    input  logic        move_right,    // Keyboard Blue Player
    input  logic        jump,          // Keyboard Blue Player
    input  logic        rmove_left,    // Pushbutton Red Player
    input  logic        rmove_right,   // Pushbutton Red Player
    input  logic        rjump_press,   // Pushbutton Red Player
    input  logic [9:0]  hcount,
    input  logic [9:0]  vcount,
    output logic [7:0]  red,
    output logic [7:0]  green,
    output logic [7:0]  blue
);
    
    // Screen Resolution and Asset Size Constants
    localparam int N_WIDE_V = 640;
    localparam int N_HIGH_V = 480;
    localparam int P_WIDTH  = 21;
    localparam int P_HEIGHT = 22	;

    // Kinematic Parameters
    localparam int RUN_SPD = 3;
    localparam signed [7:0] GRAVITY  = 8'sd1;
    localparam signed [7:0] JUMP_V   = 8'sd16;
    localparam signed [7:0] FALL_MAX = 8'sd8;

    // Spawn Locations
    localparam int SPAWN_XB = 50,  SPAWN_YB = 430-22;
    localparam int SPAWN_XR = 500, SPAWN_YR = 430-22;
	 
	 //it rectangle
	 localparam int IT_WIDTH  = 18;
	localparam int IT_HEIGHT = 5;
	localparam int IT_OFFSET = 7;

    // Dynamic Engine State Registers for Blue Player
    logic signed [10:0] blue_leftedge, blue_topedge;
    logic signed [10:0] blue_dx, blue_dy;
    logic        blue_grounded;
    logic        blue_jump_req;

    // Dynamic Engine State Registers for Red Player
    logic signed [10:0] red_leftedge, red_topedge;
    logic signed [10:0] red_dx, red_dy;
    logic        red_grounded;
    logic        red_jump_req;

    // 1-Clock Pipeline registers to match ROM latency
    logic [9:0] hcount_reg, vcount_reg;

    // Frame synchronization pulse (Triggers uniquely outside the active region)
    logic frame_tick;
    assign frame_tick = (hcount == 10'd0) && (vcount == 10'd499);

    // Wires for Concurrent ROM Address Inbound Routing
    logic [11:0] pr_addr_b, pr_addr_r;
    logic [7:0]  prr_rom_b, prg_rom_b, prb_rom_b;
    logic [7:0]  rrr_rom_r, rrg_rom_r, rrb_rom_r;

    // Instantiate Independent Framebuffers for Parallel Dual Rendering
    blue_rom_r prr_b(.clock(vga_clock), .address(pr_addr_b), .data_out(prr_rom_b));
    blue_rom_g prg_b(.clock(vga_clock), .address(pr_addr_b), .data_out(prg_rom_b));
    blue_rom_b prb_b(.clock(vga_clock), .address(pr_addr_b), .data_out(prb_rom_b));

    red_rom_r rrr_r(.clock(vga_clock), .address(pr_addr_r), .data_out(rrr_rom_r));
    red_rom_g rrg_r(.clock(vga_clock), .address(pr_addr_r), .data_out(rrg_rom_r));
    red_rom_b rrb_r(.clock(vga_clock), .address(pr_addr_r), .data_out(rrb_rom_r));

    // Safe tracking projection conversion variables
    logic [9:0] blue_x, blue_y;
    logic [9:0] red_x,  red_y;
    assign blue_x = (blue_leftedge >= 0) ? blue_leftedge[9:0] : 10'd0;
    assign blue_y = (blue_topedge >= 0)  ? blue_topedge[9:0]  : 10'd0;
    assign red_x  = (red_leftedge >= 0)  ? red_leftedge[9:0]  : 10'd0;
    assign red_y  = (red_topedge >= 0)   ? red_topedge[9:0]   : 10'd0;
	 
	 // ==========================================
	// Random "IT" Player Selection
	// ==========================================
	// 0 = Blue is IT
	// 1 = Red is IT
	
	logic       it_player;
	logic [15:0] lfsr;
	logic game_started;
	
	// Simple pseudo-random generator
	always_ff @(posedge vga_clock or negedge reset_n) begin
		 if (!reset_n) begin
			  lfsr <= 16'hACE1;
		 end
		 else begin
			  lfsr <= {
					lfsr[14:0],
					lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]
			  };
		 end
	end

    // Async Fetch Address Calculation
    always_comb begin
        pr_addr_b = 12'd0;
        if ((hcount >= blue_x) && (hcount < blue_x + P_WIDTH) && 
            (vcount >= blue_y) && (vcount < blue_y + P_HEIGHT)) begin
            pr_addr_b = 12'((vcount - blue_y) * P_WIDTH + (hcount - blue_x));
        end

        pr_addr_r = 12'd0;
        if ((hcount >= red_x) && (hcount < red_x + P_WIDTH) && 
            (vcount >= red_y) && (vcount < red_y + P_HEIGHT)) begin
            pr_addr_r = 12'((vcount - red_y) * P_WIDTH + (hcount - red_x));
        end
    end

    // Map Obstacle Query Function (Evaluates collisions for any arbitrary coordinate)
    function automatic logic check_obstacle(input int x_pos, input int y_pos);
        logic match;
        begin
            match = (y_pos >= 430) || // Floor
                    ((y_pos >= 345) && (y_pos <= 360) && (x_pos >= 50)  && (x_pos <= 175))  || // platform bottom left
                    ((y_pos >= 325) && (y_pos <= 340) && (x_pos >= 420) && (x_pos <= 520))  || // platform bottom half right 
                    ((y_pos >= 325) && (y_pos <= 340) && (x_pos >= 580) && (x_pos <= 740))  || // platform bottom full right 
                    ((y_pos >= 235) && (y_pos <= 250) && (x_pos >= 435) && (x_pos <= 580))  || // platform middle right
                    ((y_pos >= 235) && (y_pos <= 250) && (x_pos >= 0)   && (x_pos <= 190))  || // platform long bottom left
                    ((y_pos >= 180) && (y_pos <= 195) && (x_pos >= 250) && (x_pos <= 365))  || // platform middle 
                    ((y_pos >= 140) && (y_pos <= 155) && (x_pos >= 600) && (x_pos <= 740))  || // platform middle top right
                    ((y_pos >= 50)  && (y_pos <= 65)  && (x_pos >= 550) && (x_pos <= 600))  || // platform top right
                    ((y_pos >= 350) && (y_pos <= 365) && (x_pos >= 310) && (x_pos <= 340))  || // platform bottom middle
                    ((y_pos >= 60)  && (y_pos <= 75)  && (x_pos >= 275) && (x_pos <= 390))  || // platform top middle
                    ((y_pos >= 115) && (y_pos <= 130) && (x_pos >= 60)  && (x_pos <= 240))  || // platform long top left
                    ((y_pos >= 50)  && (y_pos <= 65)  && (x_pos >= 0)   && (x_pos <= 70))   || // platform top left
                    // Diagonal Geometry
                    (((x_pos >= 450) && (x_pos <= 550) && (y_pos >= (50  - (x_pos - 550)))) && (y_pos <= (65  - (x_pos - 550)))) || // top diagonal
                    (((x_pos >= 520) && (x_pos <= 575) && (y_pos >= (325 + (x_pos - 520)))) && (y_pos <= (340 + (x_pos - 520)))) || // bottom right diagonal
                    (((x_pos >= 365) && (x_pos <= 385) && (y_pos >= (180 + (x_pos - 365)))) && (y_pos <= (195 + (x_pos - 365)))) || // middle diagonal 
                    (((x_pos >= 240) && (x_pos <= 310) && (y_pos >= (280 + (x_pos - 240)))) && (y_pos <= (295 + (x_pos - 240))));   // bottom diagonal 
            return match;
        end
    endfunction

    // Main Control and Kinematics Register Update Block
    always_ff @(posedge vga_clock or negedge reset_n) begin
        if (!reset_n) begin
            // Reset Blue State Variables
            blue_leftedge  <= SPAWN_XB;
            blue_topedge   <= SPAWN_YB;
            blue_dx        <= 11'd0;
            blue_dy        <= 11'd0;
            blue_grounded  <= 1'b0;
            blue_jump_req  <= 1'b0;

            // Reset Red State Variables
            red_leftedge   <= SPAWN_XR;
            red_topedge    <= SPAWN_YR;
            red_dx         <= 11'd0;
            red_dy         <= 11'd0;
            red_grounded   <= 1'b0;
            red_jump_req   <= 1'b0;

            hcount_reg     <= 10'd0;
            vcount_reg     <= 10'd0;
				
				game_started <= 1'b0;
				it_player    <= 1'b0;
        end
        else begin
				if (!game_started) begin
					it_player    <= lfsr[0];
					game_started <= 1'b1;
				end

            // Pipeline position registers by 1 cycle to cleanly sync with ROM execution latency
            hcount_reg <= hcount;
            vcount_reg <= vcount;

            // Instantly capture async pulse input triggers from keys
            if (jump)        blue_jump_req <= 1'b1;
            if (rjump_press) red_jump_req  <= 1'b1;

            if (frame_tick) begin
                // Local tracking pointers for look-ahead kinematics projection
                logic signed [10:0] t_blue_x, t_blue_y;
                logic signed [10:0] t_red_x,  t_red_y;
                logic signed [7:0]  next_blue_dy, next_red_dy;
                logic               blue_feet, red_feet;

                // ==========================================
                // 1. PROCESS BLUE PLAYER (Keyboard Control)
                // ==========================================
                if (move_left)       blue_dx <= -RUN_SPD;
                else if (move_right) blue_dx <= RUN_SPD;
                else                 blue_dx <= 11'd0;

                if (blue_grounded && blue_jump_req) begin
                    next_blue_dy  = -JUMP_V;
                    blue_grounded <= 1'b0;
                end 
                else if (blue_dy < FALL_MAX) begin
                    next_blue_dy = blue_dy + GRAVITY;
                end 
                else begin
                    next_blue_dy = blue_dy;
                end
                
                blue_jump_req <= 1'b0; // Flag consumed
                t_blue_x = blue_leftedge + blue_dx;
                t_blue_y = blue_topedge + next_blue_dy;

                // Border boundaries clamp
                if (t_blue_x < 0)               t_blue_x = 0;
                if (t_blue_x > 640 - P_WIDTH)  t_blue_x = 640 - P_WIDTH;

                // Sample platform feet collisions across sprite base width
                blue_feet = check_obstacle(int'(t_blue_x + 3),           int'(t_blue_y + P_HEIGHT)) ||
                            check_obstacle(int'(t_blue_x + P_WIDTH -3), int'(t_blue_y + P_HEIGHT));

                if (blue_feet && (next_blue_dy >= 0)) begin
                    blue_dy       <= 11'd0;
                    blue_grounded <= 1'b1;
                    
                    // Hardware Synthesizable Collision Snapping:
                    // If player overlaps a platform block, push them up instantly without a runtime loop
                    if (check_obstacle(int'(t_blue_x + 5), int'(t_blue_y + P_HEIGHT - 1))) begin
                        // Aligns with your 15-pixel thick platform bands
                        t_blue_y = ((t_blue_y + P_HEIGHT) & 11'h7FA) - P_HEIGHT; 
                    end
                end 
                else begin
                    blue_dy       <= next_blue_dy;
                    blue_grounded <= 1'b0;
                end
                
                blue_leftedge <= t_blue_x;
                blue_topedge  <= t_blue_y;

                if (blue_topedge > N_HIGH_V) begin // Void Fall Respawn
                    blue_leftedge <= SPAWN_XB; blue_topedge <= SPAWN_YB;
                    blue_dy <= 11'd0; blue_grounded <= 1'b0;
                end

                // ==========================================
                // 2. PROCESS RED PLAYER (Pushbutton Control)
                // ==========================================
                if (rmove_left)       red_dx <= -RUN_SPD;
                else if (rmove_right) red_dx <= RUN_SPD;
                else                  red_dx <= 11'd0;

                if (red_grounded && red_jump_req) begin
                    next_red_dy  = -JUMP_V;
                    red_grounded <= 1'b0;
                end 
                else if (red_dy < FALL_MAX) begin
                    next_red_dy = red_dy + GRAVITY;
                end 
                else begin
                    next_red_dy = red_dy;
                end
                
                red_jump_req <= 1'b0; // Flag consumed
                t_red_x = red_leftedge + red_dx;
                t_red_y = red_topedge + next_red_dy;

                // Border boundaries clamp
                if (t_red_x < 0)              t_red_x = 0;
                if (t_red_x > 640 - P_WIDTH)  t_red_x = 640 - P_WIDTH;

                // Sample platform feet collisions across sprite base width
                red_feet = check_obstacle(int'(t_red_x + 3),           int'(t_red_y + P_HEIGHT)) ||
                           check_obstacle(int'(t_red_x + P_WIDTH - 3), int'(t_red_y + P_HEIGHT));

                if (red_feet && (next_red_dy >= 0)) begin
                    red_dy       <= 11'd0;
                    red_grounded <= 1'b1;
                    
                    // Hardware Synthesizable Collision Snapping
                    if (check_obstacle(int'(t_red_x + 5), int'(t_red_y + P_HEIGHT - 1))) begin
                        t_red_y = ((t_red_y + P_HEIGHT) & 11'h7FA) - P_HEIGHT;
                    end
                end 
                else begin
                    red_dy       <= next_red_dy;
                    red_grounded <= 1'b0;
                end

                red_leftedge <= t_red_x;
                red_topedge  <= t_red_y;

                if (red_topedge > N_HIGH_V) begin // Void Fall Respawn
                    red_leftedge <= SPAWN_XR; red_topedge <= SPAWN_YR;
                    red_dy <= 11'd0; red_grounded <= 1'b0;
                end
            end
            else begin
                // MANDATORY: Explicit fallback self-assignments to satisfy Quartus' structural logic compiler
                // This guarantees registers preserve their previous value when frame_tick is false, preventing latches.
                blue_leftedge <= blue_leftedge;
                blue_topedge  <= blue_topedge;
                blue_dx       <= blue_dx;
                blue_dy       <= blue_dy;
                blue_grounded <= blue_grounded;

                red_leftedge  <= red_leftedge;
                red_topedge   <= red_topedge;
                red_dx        <= red_dx;
                red_dy        <= red_dy;
                red_grounded  <= red_grounded;
            end
        end
    end

    // Video Output Display Matrix (Using delayed pipelined register inputs)
    // ==========================================
	always_comb begin
	
		 // Default background
		 red   = 8'hE1;
		 green = 8'hD2;
		 blue  = 8'hB4;
	
		 // ==========================================
		 // Layer 1: "IT" Indicator
		 // ==========================================
	
		 // BLUE is IT
		 if ((it_player == 1'b0) &&
			  (hcount_reg >= blue_x + 1) &&
			  (hcount_reg <  blue_x + 1 + IT_WIDTH) &&
			  (vcount_reg >= blue_y - IT_OFFSET - IT_HEIGHT) &&
			  (vcount_reg <  blue_y - IT_OFFSET)) begin
	
			  // "I"
			  if (
					// top bar
					((hcount_reg >= blue_x + 3) &&
					 (hcount_reg <  blue_x + 7) &&
					 (vcount_reg >= blue_y - IT_OFFSET - IT_HEIGHT) &&
					 (vcount_reg <  blue_y - IT_OFFSET - IT_HEIGHT + 1))
	
					||
	
					// middle stem
					((hcount_reg >= blue_x + 4) &&
					 (hcount_reg <  blue_x + 6) &&
					 (vcount_reg >= blue_y - IT_OFFSET - IT_HEIGHT + 1) &&
					 (vcount_reg <  blue_y - IT_OFFSET - 1))
	
					||
	
					// bottom bar
					((hcount_reg >= blue_x + 3) &&
					 (hcount_reg <  blue_x + 7) &&
					 (vcount_reg == blue_y - IT_OFFSET - 1))
			  ) begin
					red   = 8'hFF;
					green = 8'hFF;
					blue  = 8'h00;
			  end
	
			  // "T"
			  else if (
					// top bar
					((hcount_reg >= blue_x + 10) &&
					 (hcount_reg <  blue_x + 17) &&
					 (vcount_reg >= blue_y - IT_OFFSET - IT_HEIGHT) &&
					 (vcount_reg <  blue_y - IT_OFFSET - IT_HEIGHT + 1))
	
					||
	
					// vertical stem
					((hcount_reg >= blue_x + 13) &&
					 (hcount_reg <  blue_x + 15) &&
					 (vcount_reg >= blue_y - IT_OFFSET - IT_HEIGHT + 1) &&
					 (vcount_reg <  blue_y - IT_OFFSET))
			  ) begin
					red   = 8'hFF;
					green = 8'hFF;
					blue  = 8'h00;
			  end
		 end
	
	
		 // RED is IT
		 else if ((it_player == 1'b1) &&
					 (hcount_reg >= red_x + 1) &&
					 (hcount_reg <  red_x + 1 + IT_WIDTH) &&
					 (vcount_reg >= red_y - IT_OFFSET - IT_HEIGHT) &&
					 (vcount_reg <  red_y - IT_OFFSET)) begin
	
			  // "I"
			  if (
					// top bar
					((hcount_reg >= red_x + 3) &&
					 (hcount_reg <  red_x + 7) &&
					 (vcount_reg >= red_y - IT_OFFSET - IT_HEIGHT) &&
					 (vcount_reg <  red_y - IT_OFFSET - IT_HEIGHT + 1))
	
					||
	
					// middle stem
					((hcount_reg >= red_x + 4) &&
					 (hcount_reg <  red_x + 6) &&
					 (vcount_reg >= red_y - IT_OFFSET - IT_HEIGHT + 1) &&
					 (vcount_reg <  red_y - IT_OFFSET - 1))
	
					||
	
					// bottom bar
					((hcount_reg >= red_x + 3) &&
					 (hcount_reg <  red_x + 7) &&
					 (vcount_reg == red_y - IT_OFFSET - 1))
			  ) begin
					red   = 8'hFF;
					green = 8'hFF;
					blue  = 8'h00;
			  end
	
			  // "T"
			  else if (
					// top bar
					((hcount_reg >= red_x + 10) &&
					 (hcount_reg <  red_x + 17) &&
					 (vcount_reg >= red_y - IT_OFFSET - IT_HEIGHT) &&
					 (vcount_reg <  red_y - IT_OFFSET - IT_HEIGHT + 1))
	
					||
	
					// vertical stem
					((hcount_reg >= red_x + 13) &&
					 (hcount_reg <  red_x + 15) &&
					 (vcount_reg >= red_y - IT_OFFSET - IT_HEIGHT + 1) &&
					 (vcount_reg <  red_y - IT_OFFSET))
			  ) begin
					red   = 8'hFF;
					green = 8'hFF;
					blue  = 8'h00;
			  end
		 end
	
	
		 // ==========================================
		 // Layer 2: Blue Player Sprite
		 // ==========================================
		 else if ((hcount_reg >= blue_x) &&
					 (hcount_reg < blue_x + P_WIDTH) &&
					 (vcount_reg >= blue_y) &&
					 (vcount_reg < blue_y + P_HEIGHT)) begin
	
			  red   = prr_rom_b << 4;
			  green = prg_rom_b << 4;
			  blue  = prb_rom_b << 4;
		 end
	
	
		 // ==========================================
		 // Layer 3: Red Player Sprite
		 // ==========================================
		 else if ((hcount_reg >= red_x) &&
					 (hcount_reg < red_x + P_WIDTH) &&
					 (vcount_reg >= red_y) &&
					 (vcount_reg < red_y + P_HEIGHT)) begin
	
			  red   = rrr_rom_r << 4;
			  green = rrg_rom_r << 4;
			  blue  = rrb_rom_r << 4;
		 end
	
	
		 // ==========================================
		 // Layer 4: Static Platforms
		 // ==========================================
		 else if (check_obstacle(int'(hcount_reg), int'(vcount_reg))) begin
	
			  red   = 8'h40;
			  green = 8'h40;
			  blue  = 8'h40;
		 end
	end

endmodule
