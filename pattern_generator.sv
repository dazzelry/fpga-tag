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
	 
	 // SCOREBOARD

	 logic [3:0] score_blue_tens;
	 logic [3:0] score_blue_ones;
	 logic [3:0] score_red_tens;
	 logic [3:0] score_red_ones;

	 logic [6:0] segments_blue_tens;
	 logic [6:0] segments_blue_ones;
	 logic [6:0] segments_red_tens;
	 logic [6:0] segments_red_ones;

	 logic score_blue_tens_pixel;
	 logic score_blue_ones_pixel;
	 logic score_red_tens_pixel;
	 logic score_red_ones_pixel;

    // Kinematic Parameters
    localparam int RUN_SPD = 3;
    localparam signed [7:0] GRAVITY  = 8'sd1;
    localparam signed [7:0] JUMP_V   = 8'sd16;
    localparam signed [7:0] FALL_MAX = 8'sd8;

    // Spawn Locations
    localparam int SPAWN_XB = 50,  SPAWN_YB = 430-22;
    localparam int SPAWN_XR = 500, SPAWN_YR = 430-22;
	 
	 //it rectangle
	 localparam int IT_WIDTH = 18;
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
	 
	 logic [7:0]  score_blue;
	 logic [7:0]  score_red;

	 logic [5:0]  score_timer;
	 logic        game_over;
	 logic [8:0]  start_delay_timer;
	 logic [1:0]  countdown_timer;
	 logic        countdown_active;
	 logic        game_active;

	 localparam int START_DELAY_FRAMES = 300; // 5 seconds at 60 FPS
	 localparam int COUNTDOWN_FRAMES   = 180; // 3 seconds at 60 FPS

	 localparam int FRAMES_PER_SECOND = 60;
	
	// Convert binary scores into decimal digits
		always_comb begin
		 score_blue_tens = score_blue / 10;
		 score_blue_ones = score_blue % 10;

		 score_red_tens = score_red / 10;
		 score_red_ones = score_red % 10;
	 end
	 
	 //segment mapping for scoreboard
	 // =============================
	 
	 always_comb begin

    // Blue tens
	 
		case (score_blue_tens)
        4'd0: segments_blue_tens = 7'b1111110;
        4'd1: segments_blue_tens = 7'b0000110;
        4'd2: segments_blue_tens = 7'b1101101;
        4'd3: segments_blue_tens = 7'b1111001;
        4'd4: segments_blue_tens = 7'b0110011;
        4'd5: segments_blue_tens = 7'b1011011;
        4'd6: segments_blue_tens = 7'b1011111;
        4'd7: segments_blue_tens = 7'b1110000;
        4'd8: segments_blue_tens = 7'b1111111;
        4'd9: segments_blue_tens = 7'b1111011;
        default: segments_blue_tens = 7'b0000000;
    endcase

    // Blue ones
  
		case (score_blue_ones)
        4'd0: segments_blue_ones = 7'b1111110;
        4'd1: segments_blue_ones = 7'b0000110;
        4'd2: segments_blue_ones = 7'b1101101;
        4'd3: segments_blue_ones = 7'b1111001;
        4'd4: segments_blue_ones = 7'b0110011;
        4'd5: segments_blue_ones = 7'b1011011;
        4'd6: segments_blue_ones = 7'b1011111;
        4'd7: segments_blue_ones = 7'b1110000;
        4'd8: segments_blue_ones = 7'b1111111;
        4'd9: segments_blue_ones = 7'b1111011;
        default: segments_blue_ones = 7'b0000000;
		endcase

    // Red tens
    
		case (score_red_tens)
        4'd0: segments_red_tens = 7'b1111110;
        4'd1: segments_red_tens = 7'b0000110;
        4'd2: segments_red_tens = 7'b1101101;
        4'd3: segments_red_tens = 7'b1111001;
        4'd4: segments_red_tens = 7'b0110011;
        4'd5: segments_red_tens = 7'b1011011;
        4'd6: segments_red_tens = 7'b1011111;
        4'd7: segments_red_tens = 7'b1110000;
        4'd8: segments_red_tens = 7'b1111111;
        4'd9: segments_red_tens = 7'b1111011;
        default: segments_red_tens = 7'b0000000;
    endcase

    // Red ones
    
    case (score_red_ones)
        4'd0: segments_red_ones = 7'b1111110;
        4'd1: segments_red_ones = 7'b0000110;
        4'd2: segments_red_ones = 7'b1101101;
        4'd3: segments_red_ones = 7'b1111001;
        4'd4: segments_red_ones = 7'b0110011;
        4'd5: segments_red_ones = 7'b1011011;
        4'd6: segments_red_ones = 7'b1011111;
        4'd7: segments_red_ones = 7'b1110000;
        4'd8: segments_red_ones = 7'b1111111;
        4'd9: segments_red_ones = 7'b1111011;
        default: segments_red_ones = 7'b0000000;
    endcase
	end
	
	// scoreboard location
	
// BLUE SCORE - TENS

always_comb begin
    score_blue_tens_pixel = 1'b0;

    // Segment A - top
    if (segments_blue_tens[6] &&
        (hcount >= 10'd186) && (hcount <= 10'd220) &&
        (vcount >= 10'd435) && (vcount <= 10'd440))
        score_blue_tens_pixel = 1'b1;

    // Segment B - upper right
    else if (segments_blue_tens[5] &&
             (hcount >= 10'd215) && (hcount <= 10'd220) &&
             (vcount >= 10'd435) && (vcount <= 10'd454))
        score_blue_tens_pixel = 1'b1;

    // Segment C - lower right
    else if (segments_blue_tens[4] &&
             (hcount >= 10'd215) && (hcount <= 10'd220) &&
             (vcount >= 10'd456) && (vcount <= 10'd475))
        score_blue_tens_pixel = 1'b1;

    // Segment D - bottom
    else if (segments_blue_tens[3] &&
             (hcount >= 10'd186) && (hcount <= 10'd220) &&
             (vcount >= 10'd470) && (vcount <= 10'd475))
        score_blue_tens_pixel = 1'b1;

    // Segment E - lower left
    else if (segments_blue_tens[2] &&
             (hcount >= 10'd186) && (hcount <= 10'd191) &&
             (vcount >= 10'd456) && (vcount <= 10'd475))
        score_blue_tens_pixel = 1'b1;

    // Segment F - upper left
    else if (segments_blue_tens[1] &&
             (hcount >= 10'd186) && (hcount <= 10'd191) &&
             (vcount >= 10'd435) && (vcount <= 10'd454))
        score_blue_tens_pixel = 1'b1;

    // Segment G - middle
    else if (segments_blue_tens[0] &&
             (hcount >= 10'd186) && (hcount <= 10'd220) &&
             (vcount >= 10'd455) && (vcount <= 10'd460))
        score_blue_tens_pixel = 1'b1;
end


// BLUE SCORE - ONES

always_comb begin
    score_blue_ones_pixel = 1'b0;

    // Segment A - top
    if (segments_blue_ones[6] &&
        (hcount >= 10'd226) && (hcount <= 10'd260) &&
        (vcount >= 10'd435) && (vcount <= 10'd440))
        score_blue_ones_pixel = 1'b1;

    // Segment B - upper right
    else if (segments_blue_ones[5] &&
             (hcount >= 10'd255) && (hcount <= 10'd260) &&
             (vcount >= 10'd435) && (vcount <= 10'd454))
        score_blue_ones_pixel = 1'b1;

    // Segment C - lower right
    else if (segments_blue_ones[4] &&
             (hcount >= 10'd255) && (hcount <= 10'd260) &&
             (vcount >= 10'd456) && (vcount <= 10'd475))
        score_blue_ones_pixel = 1'b1;

    // Segment D - bottom
    else if (segments_blue_ones[3] &&
             (hcount >= 10'd226) && (hcount <= 10'd260) &&
             (vcount >= 10'd470) && (vcount <= 10'd475))
        score_blue_ones_pixel = 1'b1;

    // Segment E - lower left
    else if (segments_blue_ones[2] &&
             (hcount >= 10'd226) && (hcount <= 10'd231) &&
             (vcount >= 10'd456) && (vcount <= 10'd475))
        score_blue_ones_pixel = 1'b1;

    // Segment F - upper left
    else if (segments_blue_ones[1] &&
             (hcount >= 10'd226) && (hcount <= 10'd231) &&
             (vcount >= 10'd435) && (vcount <= 10'd454))
        score_blue_ones_pixel = 1'b1;

    // Segment G - middle
    else if (segments_blue_ones[0] &&
             (hcount >= 10'd226) && (hcount <= 10'd260) &&
             (vcount >= 10'd455) && (vcount <= 10'd460))
        score_blue_ones_pixel = 1'b1;
end


// RED SCORE - TENS

always_comb begin
    score_red_tens_pixel = 1'b0;

    // Segment A - top
    if (segments_red_tens[6] &&
        (hcount >= 10'd380) && (hcount <= 10'd414) &&
        (vcount >= 10'd435) && (vcount <= 10'd440))
        score_red_tens_pixel = 1'b1;

    // Segment B - upper right
    else if (segments_red_tens[5] &&
             (hcount >= 10'd409) && (hcount <= 10'd414) &&
             (vcount >= 10'd435) && (vcount <= 10'd454))
        score_red_tens_pixel = 1'b1;

    // Segment C - lower right
    else if (segments_red_tens[4] &&
             (hcount >= 10'd409) && (hcount <= 10'd414) &&
             (vcount >= 10'd456) && (vcount <= 10'd475))
        score_red_tens_pixel = 1'b1;

    // Segment D - bottom
    else if (segments_red_tens[3] &&
             (hcount >= 10'd380) && (hcount <= 10'd414) &&
             (vcount >= 10'd470) && (vcount <= 10'd475))
        score_red_tens_pixel = 1'b1;

    // Segment E - lower left
    else if (segments_red_tens[2] &&
             (hcount >= 10'd380) && (hcount <= 10'd385) &&
             (vcount >= 10'd456) && (vcount <= 10'd475))
        score_red_tens_pixel = 1'b1;

    // Segment F - upper left
    else if (segments_red_tens[1] &&
             (hcount >= 10'd380) && (hcount <= 10'd385) &&
             (vcount >= 10'd435) && (vcount <= 10'd454))
        score_red_tens_pixel = 1'b1;

    // Segment G - middle
    else if (segments_red_tens[0] &&
             (hcount >= 10'd380) && (hcount <= 10'd414) &&
             (vcount >= 10'd455) && (vcount <= 10'd460))
        score_red_tens_pixel = 1'b1;
end


// RED SCORE - ONES

always_comb begin
    score_red_ones_pixel = 1'b0;

    // Segment A - top
    if (segments_red_ones[6] &&
        (hcount >= 10'd420) && (hcount <= 10'd454) &&
        (vcount >= 10'd435) && (vcount <= 10'd440))
        score_red_ones_pixel = 1'b1;

    // Segment B - upper right
    else if (segments_red_ones[5] &&
             (hcount >= 10'd449) && (hcount <= 10'd454) &&
             (vcount >= 10'd435) && (vcount <= 10'd454))
        score_red_ones_pixel = 1'b1;

    // Segment C - lower right
    else if (segments_red_ones[4] &&
             (hcount >= 10'd449) && (hcount <= 10'd454) &&
             (vcount >= 10'd456) && (vcount <= 10'd475))
        score_red_ones_pixel = 1'b1;

    // Segment D - bottom
    else if (segments_red_ones[3] &&
             (hcount >= 10'd420) && (hcount <= 10'd454) &&
             (vcount >= 10'd470) && (vcount <= 10'd475))
        score_red_ones_pixel = 1'b1;

    // Segment E - lower left
    else if (segments_red_ones[2] &&
             (hcount >= 10'd420) && (hcount <= 10'd425) &&
             (vcount >= 10'd456) && (vcount <= 10'd475))
        score_red_ones_pixel = 1'b1;

    // Segment F - upper left
    else if (segments_red_ones[1] &&
             (hcount >= 10'd420) && (hcount <= 10'd425) &&
             (vcount >= 10'd435) && (vcount <= 10'd454))
        score_red_ones_pixel = 1'b1;

    // Segment G - middle
    else if (segments_red_ones[0] &&
             (hcount >= 10'd420) && (hcount <= 10'd454) &&
             (vcount >= 10'd455) && (vcount <= 10'd460))
        score_red_ones_pixel = 1'b1;
end

    // Instantiate Independent Framebuffers for Parallel Dual Rendering
    BLU_rom_r prr_b(.clock(vga_clock), .address(pr_addr_b), .data_out(prr_rom_b));
    BLU_rom_g prg_b(.clock(vga_clock), .address(pr_addr_b), .data_out(prg_rom_b));
    BLU_rom_b prb_b(.clock(vga_clock), .address(pr_addr_b), .data_out(prb_rom_b));

    RED_rom_r rrr_r(.clock(vga_clock), .address(pr_addr_r), .data_out(rrr_rom_r));
    RED_rom_g rrg_r(.clock(vga_clock), .address(pr_addr_r), .data_out(rrg_rom_r));
    RED_rom_b rrb_r(.clock(vga_clock), .address(pr_addr_r), .data_out(rrb_rom_r));

    // Safe tracking projection conversion variables
    logic [9:0] blue_x, blue_y;
    logic [9:0] red_x,  red_y;
    assign blue_x = (blue_leftedge >= 0) ? blue_leftedge[9:0] : 10'd0;
    assign blue_y = (blue_topedge >= 0)  ? blue_topedge[9:0]  : 10'd0;
    assign red_x  = (red_leftedge >= 0)  ? red_leftedge[9:0]  : 10'd0;
    assign red_y  = (red_topedge >= 0)   ? red_topedge[9:0]   : 10'd0;

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
	 
	 //random "it" player selection
	 //0 = blue is it; 1 = red is it
	 
	 logic it_player;
	 logic [15:0] lfsr;
	 logic signed [10:0] t_blue_x, t_blue_y;
	logic signed [10:0] t_red_x, t_red_y;
	logic signed [7:0]  next_blue_dy, next_red_dy;
	logic               blue_feet, red_feet;
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
	
	logic game_started;
	localparam int TAG_COOLDOWN_FRAMES = 30;
	logic [5:0] tag_cooldown;

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
				it_player <= 1'b0;
				
				tag_cooldown <= 6'd0;
				
				score_blue <= 8'd0;
				score_red  <= 8'd0;
				
				score_timer       <= 6'd0;
				game_over         <= 1'b0;

				start_delay_timer <= START_DELAY_FRAMES;
				countdown_timer   <= 2'd3;
				countdown_active  <= 1'b0;
				game_active       <= 1'b0;
        end
        else begin
		  
				if (!game_started) begin
					it_player <= lfsr[0];
					game_started <= 1'b1;
				end
            // Pipeline position registers by 1 cycle to cleanly sync with ROM execution latency
            hcount_reg <= hcount;
            vcount_reg <= vcount;

            // Instantly capture async pulse input triggers from keys
            if (jump)        blue_jump_req <= 1'b1;
            if (rjump_press) red_jump_req  <= 1'b1;

            if (frame_tick) begin

    // ==========================================
    // START DELAY + COUNTDOWN
    // ==========================================

    if (start_delay_timer > 0) begin

        // 5-second delay before countdown begins
        start_delay_timer <= start_delay_timer - 1'b1;
        game_active      <= 1'b0;
        countdown_active <= 1'b0;

    end

    else if (countdown_timer > 0) begin

        // 3-second countdown
        countdown_active <= 1'b1;
        game_active      <= 1'b0;

        countdown_timer <= countdown_timer - 1'b1;

    end

    else begin

        // Countdown finished — START GAME
        countdown_active <= 1'b0;
        game_active      <= 1'b1;

    end



					 
					 // ============================================================
					// SCORE TIMER
					// One score opportunity every ~1 second
					// ============================================================
					
					if (game_active && !game_over) begin					
						 if (score_timer == FRAMES_PER_SECOND - 1) begin
					
							  score_timer <= 6'd0;
					
							  // Player who is NOT IT gets a point
							  if (it_player == 1'b0) begin
									// Blue is IT, so Red scores
									score_red <= score_red + 8'd1;
					
									// Red reaches 30
									if (score_red == 8'd44) begin
										 game_over   <= 1'b1;
										 game_started <= 1'b0;
									end
							  end
					
							  else begin
									// Red is IT, so Blue scores
									score_blue <= score_blue + 8'd1;
					
									// Blue reaches 30
									if (score_blue == 8'd44) begin
										 game_over   <= 1'b1;
										 game_started <= 1'b0;
									end
							  end
						 end
					
						 else begin
							  score_timer <= score_timer + 6'd1;
						 end
					
					end
					 
					 // Count down tag cooldown
					if (tag_cooldown > 0) begin
						 tag_cooldown <= tag_cooldown - 1'b1;
					end
					
					// Check if players are touching
					if ((tag_cooldown == 0) &&
						 (blue_leftedge < red_leftedge + P_WIDTH) &&
						 (blue_leftedge + P_WIDTH > red_leftedge) &&
						 (blue_topedge < red_topedge + P_HEIGHT) &&
						 (blue_topedge + P_HEIGHT > red_topedge)) begin
					
						 // Blue is IT -> Red becomes IT
						 if (it_player == 1'b0) begin
							  it_player    <= 1'b1;
							  tag_cooldown <= TAG_COOLDOWN_FRAMES;
						 end
					
						 // Red is IT -> Blue becomes IT
						 else begin
							  it_player    <= 1'b0;
							  tag_cooldown <= TAG_COOLDOWN_FRAMES;
						 end
					end


               // ==========================================
					// 1. PROCESS BLUE PLAYER (Hitbox: 21x22)
					// ==========================================
				if (game_active) begin

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
                
                blue_jump_req <= 1'b0; 
                t_blue_x = blue_leftedge + blue_dx;
                t_blue_y = blue_topedge + next_blue_dy;

                if (t_blue_x < 0)        t_blue_x = 0;
                if (t_blue_x > 640 - 21) t_blue_x = 640 - 21;

                // Test feet contact points
                blue_feet = check_obstacle(int'(t_blue_x + 3),  int'(t_blue_y + 22)) ||
                            check_obstacle(int'(t_blue_x + 18), int'(t_blue_y + 22));

                if (blue_feet && (next_blue_dy >= 0)) begin
                    blue_dy       <= 11'd0;
                    blue_grounded <= 1'b1;
                    
                    // --- DYNAMIC DIAGONAL SLOPE RIDERS ---
                    // 1. Top Diagonal Slope
                    if ((t_blue_x + 10 >= 450) && (t_blue_x + 10 <= 550) && 
                        (t_blue_y + 22 >= (50 - (t_blue_x + 10 - 550)) - 10) && 
                        (t_blue_y + 22 <= (65 - (t_blue_x + 10 - 550)) + 10)) begin
                        t_blue_y = (50 - (t_blue_x + 10 - 550)) - 22;
                    end
                    // 2. Bottom Right Diagonal Slope
                    else if ((t_blue_x + 10 >= 520) && (t_blue_x + 10 <= 575) && 
                             (t_blue_y + 22 >= (325 + (t_blue_x + 10 - 520)) - 10) && 
                             (t_blue_y + 22 <= (340 + (t_blue_x + 10 - 520)) + 10)) begin
                        t_blue_y = (325 + (t_blue_x + 10 - 520)) - 22;
                    end
                    // 3. Middle Diagonal Slope
                    else if ((t_blue_x + 10 >= 365) && (t_blue_x + 10 <= 385) && 
                             (t_blue_y + 22 >= (180 + (t_blue_x + 10 - 365)) - 10) && 
                             (t_blue_y + 22 <= (195 + (t_blue_x + 10 - 365)) + 10)) begin
                        t_blue_y = (180 + (t_blue_x + 10 - 365)) - 22;
                    end
                    // 4. Bottom Diagonal Slope
                    else if ((t_blue_x + 10 >= 240) && (t_blue_x + 10 <= 310) && 
                             (t_blue_y + 22 >= (280 + (t_blue_x + 10 - 240)) - 10) && 
                             (t_blue_y + 22 <= (295 + (t_blue_x + 10 - 240)) + 10)) begin
                        t_blue_y = (280 + (t_blue_x + 10 - 240)) - 22;
                    end
                    
                    // --- STATIC HORIZONTAL FLAT PLATFORMS ---
                    else if (t_blue_y + 22 >= 430) begin
                        t_blue_y = 430 - 22; // Ground
                    end
                    else if ((t_blue_y + 22 >= 345) && (t_blue_y + 22 <= 365) && (t_blue_x + 10 >= 50) && (t_blue_x + 10 <= 175)) begin
                        t_blue_y = 345 - 22; // Platform Bottom Left
                    end
                    else if ((t_blue_y + 22 >= 325) && (t_blue_y + 22 <= 345) && (t_blue_x + 10 >= 420) && (t_blue_x + 10 <= 520)) begin
                        t_blue_y = 325 - 22; // Platform Bottom Half Right
                    end
                    else if ((t_blue_y + 22 >= 325) && (t_blue_y + 22 <= 345) && (t_blue_x + 10 >= 580) && (t_blue_x + 10 <= 740)) begin
                        t_blue_y = 325 - 22; // Platform Bottom Full Right
                    end
                    else if ((t_blue_y + 22 >= 235) && (t_blue_y + 22 <= 255) && (t_blue_x + 10 >= 435) && (t_blue_x + 10 <= 580)) begin
                        t_blue_y = 235 - 22; // Platform Middle Right
                    end
                    else if ((t_blue_y + 22 >= 235) && (t_blue_y + 22 <= 255) && (t_blue_x + 10 >= 0) && (t_blue_x + 10 <= 190)) begin
                        t_blue_y = 235 - 22; // Platform Long Bottom Left
                    end
                    else if ((t_blue_y + 22 >= 180) && (t_blue_y + 22 <= 200) && (t_blue_x + 10 >= 250) && (t_blue_x + 10 <= 365)) begin
                        t_blue_y = 180 - 22; // Platform Middle
                    end
                    else if ((t_blue_y + 22 >= 140) && (t_blue_y + 22 <= 160) && (t_blue_x + 10 >= 600) && (t_blue_x + 10 <= 740)) begin
                        t_blue_y = 140 - 22; // Platform Middle Top Right
                    end
                    else if ((t_blue_y + 22 >= 50) && (t_blue_y + 22 <= 70) && (t_blue_x + 10 >= 550) && (t_blue_x + 10 <= 600)) begin
                        t_blue_y = 50 - 22;  // Platform Top Right
                    end
                    else if ((t_blue_y + 22 >= 350) && (t_blue_y + 22 <= 370) && (t_blue_x + 10 >= 310) && (t_blue_x + 10 <= 340)) begin
                        t_blue_y = 350 - 22; // Platform Bottom Middle
                    end
                    else if ((t_blue_y + 22 >= 60) && (t_blue_y + 22 <= 80) && (t_blue_x + 10 >= 275) && (t_blue_x + 10 <= 390)) begin
                        t_blue_y = 60 - 22;  // Platform Top Middle
                    end
                    else if ((t_blue_y + 22 >= 115) && (t_blue_y + 22 <= 135) && (t_blue_x + 10 >= 60) && (t_blue_x + 10 <= 240)) begin
                        t_blue_y = 115 - 22; // Platform Long Top Left
                    end
                    else if ((t_blue_y + 22 >= 50) && (t_blue_y + 22 <= 70) && (t_blue_x + 10 >= 0) && (t_blue_x + 10 <= 70)) begin
                        t_blue_y = 50 - 22;  // Platform Top Left
                    end
                end 
                else begin
                    blue_dy       <= next_blue_dy;
                    blue_grounded <= 1'b0;
                end
                
                blue_leftedge <= t_blue_x;
                blue_topedge  <= t_blue_y;

                if (blue_topedge > N_HIGH_V) begin 
                    blue_leftedge <= SPAWN_XB; blue_topedge <= SPAWN_YB;
                    blue_dy <= 11'd0; blue_grounded <= 1'b0;
                end
					end

               // ==========================================
					// 1. PROCESS RED PLAYER (Hitbox: 21x22)
					// ==========================================
					if (game_active) begin

					if (move_left)       red_dx <= -RUN_SPD;
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
                
                red_jump_req <= 1'b0; 
                t_red_x = red_leftedge + red_dx;
                t_red_y = red_topedge + next_red_dy;

                if (t_red_x < 0)        t_red_x = 0;
                if (t_red_x > 640 - 21) t_red_x = 640 - 21;

                red_feet = check_obstacle(int'(t_red_x + 3),  int'(t_red_y + 22)) ||
                           check_obstacle(int'(t_red_x + 18), int'(t_red_y + 22));

                if (red_feet && (next_red_dy >= 0)) begin
                    red_dy       <= 11'd0;
                    red_grounded <= 1'b1;
                    
                    // --- DYNAMIC DIAGONAL SLOPE RIDERS ---
                    // 1. Top Diagonal Slope
                    if ((t_red_x + 10 >= 450) && (t_red_x + 10 <= 550) && 
                        (t_red_y + 22 >= (50 - (t_red_x + 10 - 550)) - 10) && 
                        (t_red_y + 22 <= (65 - (t_red_x + 10 - 550)) + 10)) begin
                        t_red_y = (50 - (t_red_x + 10 - 550)) - 22;
                    end
                    // 2. Bottom Right Diagonal Slope
                    else if ((t_red_x + 10 >= 520) && (t_red_x + 10 <= 575) && 
                             (t_red_y + 22 >= (325 + (t_red_x + 10 - 520)) - 10) && 
                             (t_red_y + 22 <= (340 + (t_red_x + 10 - 520)) + 10)) begin
                        t_red_y = (325 + (t_red_x + 10 - 520)) - 22;
                    end
                    // 3. Middle Diagonal Slope
                    else if ((t_red_x + 10 >= 365) && (t_red_x + 10 <= 385) && 
                             (t_red_y + 22 >= (180 + (t_red_x + 10 - 365)) - 10) && 
                             (t_red_y + 22 <= (195 + (t_red_x + 10 - 365)) + 10)) begin
                        t_red_y = (180 + (t_red_x + 10 - 365)) - 22;
                    end
                    // 4. Bottom Diagonal Slope
                    else if ((t_red_x + 10 >= 240) && (t_red_x + 10 <= 310) && 
                             (t_red_y + 22 >= (280 + (t_red_x + 10 - 240)) - 10) && 
                             (t_red_y + 22 <= (295 + (t_red_x + 10 - 240)) + 10)) begin
                        t_red_y = (280 + (t_red_x + 10 - 240)) - 22;
                    end
                    
                    // --- STATIC HORIZONTAL FLAT PLATFORMS ---
                    else if (t_red_y + 22 >= 430) begin
                        t_red_y = 430 - 22; // Ground
                    end
                    else if ((t_red_y + 22 >= 345) && (t_red_y + 22 <= 365) && (t_red_x + 10 >= 50) && (t_red_x + 10 <= 175)) begin
                        t_red_y = 345 - 22; // Platform Bottom Left
                    end
                    else if ((t_red_y + 22 >= 325) && (t_red_y + 22 <= 345) && (t_red_x + 10 >= 420) && (t_red_x + 10 <= 520)) begin
                        t_red_y = 325 - 22; // Platform Bottom Half Right
                    end
                    else if ((t_red_y + 22 >= 325) && (t_red_y + 22 <= 345) && (t_red_x + 10 >= 580) && (t_red_x + 10 <= 740)) begin
                        t_red_y = 325 - 22; // Platform Bottom Full Right
                    end
                    else if ((t_red_y + 22 >= 235) && (t_red_y + 22 <= 255) && (t_red_x + 10 >= 435) && (t_red_x + 10 <= 580)) begin
                        t_red_y = 235 - 22; // Platform Middle Right
                    end
                    else if ((t_red_y + 22 >= 235) && (t_red_y + 22 <= 255) && (t_red_x + 10 >= 0) && (t_red_x + 10 <= 190)) begin
                        t_red_y = 235 - 22; // Platform Long Bottom Left
                    end
                    else if ((t_red_y + 22 >= 180) && (t_red_y + 22 <= 200) && (t_red_x + 10 >= 250) && (t_red_x + 10 <= 365)) begin
                        t_red_y = 180 - 22; // Platform Middle
                    end
                    else if ((t_red_y + 22 >= 140) && (t_red_y + 22 <= 160) && (t_red_x + 10 >= 600) && (t_red_x + 10 <= 740)) begin
                        t_red_y = 140 - 22; // Platform Middle Top Right
                    end
                    else if ((t_red_y + 22 >= 50) && (t_red_y + 22 <= 70) && (t_red_x + 10 >= 550) && (t_red_x + 10 <= 600)) begin
                        t_red_y = 50 - 22;  // Platform Top Right
                    end
                    else if ((t_red_y + 22 >= 350) && (t_red_y + 22 <= 370) && (t_red_x + 10 >= 310) && (t_red_x + 10 <= 340)) begin
                        t_red_y = 350 - 22; // Platform Bottom Middle
                    end
                    else if ((t_red_y + 22 >= 60) && (t_red_y + 22 <= 80) && (t_red_x + 10 >= 275) && (t_red_x + 10 <= 390)) begin
                        t_red_y = 60 - 22;  // Platform Top Middle
                    end
                    else if ((t_red_y + 22 >= 115) && (t_red_y + 22 <= 135) && (t_red_x + 10 >= 60) && (t_red_x + 10 <= 240)) begin
                        t_red_y = 115 - 22; // Platform Long Top Left
                    end
                    else if ((t_red_y + 22 >= 50) && (t_red_y + 22 <= 70) && (t_red_x + 10 >= 0) && (t_red_x + 10 <= 70)) begin
                        t_red_y = 50 - 22;  // Platform Top Left
                    end
                end 
                else begin
                    red_dy       <= next_red_dy;
                    red_grounded <= 1'b0;
                end

                red_leftedge <= t_red_x;
                red_topedge  <= t_red_y;

                if (red_topedge > N_HIGH_V) begin 
                    red_leftedge <= SPAWN_XR; red_topedge <= SPAWN_YR;
                    red_dy <= 11'd0; red_grounded <= 1'b0;
                end
            end
			end
            else begin
                // MANDATORY: Explicit fallback self-assignments to satisfy Quartus' structural logic compiler
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
    always_comb begin
	
		 // Default background
		 red   = 8'hD2;
		 green = 8'hEE;
		 blue  = 8'hF5;

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
					green = 8'h00;
					blue  = 8'hFF;
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
					green = 8'h00;
					blue  = 8'hFF;
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
	
					// bottom barff
					((hcount_reg >= red_x + 3) &&
					 (hcount_reg <  red_x + 7) &&
					 (vcount_reg == red_y - IT_OFFSET - 1))
			  ) begin
					red   = 8'hFF;
					green = 8'h00;
					blue  = 8'hFF;
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
					green = 8'h00;
					blue  = 8'hFF;
			  end
		 end
	
	
		 // ==========================================
		// Layer 2: Blue Player Sprite
		// ==========================================
		else if ((hcount_reg >= blue_x) &&
					(hcount_reg < blue_x + P_WIDTH) &&
					(vcount_reg >= blue_y) &&
					(vcount_reg < blue_y + P_HEIGHT) &&
					(prr_rom_b != 0) &&
					(prg_rom_b != 0) &&
					(prb_rom_b != 0)) begin
		
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
					(vcount_reg < red_y + P_HEIGHT) &&
					((rrr_rom_r != 0) ||
					 (rrg_rom_r != 0) ||
					 (rrb_rom_r != 0))) begin
		
			 red   = rrr_rom_r << 4;
			 green = rrg_rom_r << 4;
			 blue  = rrb_rom_r << 4;
		end
	
	
		 // ==========================================
// Layer 4: Static Platforms
// ==========================================
else if (check_obstacle(int'(hcount_reg), int'(vcount_reg))) begin

    red   = 8'h69;
    green = 8'hA5;
    blue  = 8'h73;
end


// ==========================================
// Layer 5: Scoreboard Background
// ==========================================
if ((hcount_reg >= 10'd170) &&
    (hcount_reg <= 10'd470) &&
    (vcount_reg >= 10'd430) &&
    (vcount_reg <= 10'd479)) begin

    red   = 8'hB7;
    green = 8'hE8;
    blue  = 8'hB9;
end


// ==========================================
// Layer 6: Scoreboard Digits
// ==========================================
	if (score_blue_tens_pixel ||
		score_blue_ones_pixel ||
		score_red_tens_pixel ||
		score_red_ones_pixel) begin

		red   = 8'h55;
		green = 8'h55;
		blue  = 8'h55;
		
	  end
	end


endmodule
