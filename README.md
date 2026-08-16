A two-player game of tag implemented entirely in SystemVerilog and designed to run on an FPGA with VGA output. Players move around a platform-based environment, jump between platforms, and try to tag each other. The player who is currently IT is indicated on-screen.

The project is designed for an FPGA development board with:
VGA output
Keyboard input
FPGA clock
Sufficient memory/logic resources for sprite ROMs and game logic

Player 1 uses KEY3 left, KEY2 jump, KEY1 right. Player 2 uses the arrow keys of an external keyboard input to move.

D flip-flops provide the state storage required by the game. Clocked registers implemented using DFFs store player positions, velocities, jump states, the current IT player, and tag cooldowns. Combinational logic calculates the next game state, which is then captured by the registers on each clock cycle.

Main Modules

top.sv

The top-level module connecting the FPGA inputs, VGA controller, clock generation, and game logic.

vga_controller.sv

Generates the VGA timing signals and keeps track of the current horizontal and vertical pixel coordinates.

pattern_generator.sv

Contains the main game rendering and gameplay logic. It determines what should appear at each pixel and manages player movement, physics, platforms, collision detection, IT selection, and tagging.

clock_generator.v

Generates the clock signals required by the VGA system.
