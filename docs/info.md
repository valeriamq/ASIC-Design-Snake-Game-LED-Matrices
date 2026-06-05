<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project is an implementation of the classic game ‘Snake’. It operates entirely as a synchronous digital system, driven by a 50 MHz clock, with a display consisting of four 8×8 matrices and controlled by four push-button switches to determine the direction.

The architecture consists of four main blocks:
1. **snake_top:** The game’s main module, which handles input and output management. It processes conditions relating to an anti-bounce filter, a clock divider for the SPI_diver module, and a BCD and binary decoder for the score
2. **Game core:** manages the game logic using a finite state machine. It updates the snake’s position, detects collisions (with the walls or its own body), tracks the coordinates of the food, manages the score and generates a poisonous block that flashes periodically to increase the difficulty.
3. **SPI Controller:** coordinates the transmission of a 64-bit frame to an 8x8, 4-unit LED matrix display controlled by a MAX7219 to draw the game board in real time.
4. **7-segment display decoder:** assigns the current score to two physical 7-segment displays (units and tens) using BCD conversion logic.

## How to test

1. **Reset the game:** Toggle the Reset switch (`rst_n` / SW0) to low (`0`) and then high (`1`) to initialize the snake position, food placement, and reset the score.
2. **Control the movement:** Use the dedicated input pins (`ui_in[3:0]`) to change the snake's heading:
   - `ui_in[0]`: Move Right
   - `ui_in[1]`: Move Down
   - `ui_in[2]`: Move Left
   - `ui_in[3]`: Move Up
3. **Gameplay:** Eat the standard static food blocks to grow and increase your score. Avoid hitting the borders, your own body, or the fast-blinking poison blocks. If you die, the LED matrix will completely light up, and the game will auto-restart after 3 seconds.

## External hardware

To play the game on a physical board, you will need:
- A generic **MAX7219 4-in-1 8x8 LED Matrix Display** module (connected via the SPI pins: `MAX_DIN`, `MAX_CLK`, `MAX_CS`).
- Two standard **Common Anode 7-Segment Displays** (connected to the `HEX0` and `HEX1` outputs mapped on `uo_out` and `uio_out`).
- 4 tactile push-buttons for direction inputs.