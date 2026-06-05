![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

## ASIC-Design-Snake-Game-LED-Matrices

This repository contains the synchronous, hardware-only Register-Transfer Level (RTL) architecture in Verilog HDL for a special-purpose processor designed to execute the game "Snake". The design implements state routines, collision matrices, and peripheral drivers.
---

## System Architecture & Block Topography

* **`tt_um_example`**: The primary physical pad frame wrapper required by the Tiny Tapeout multi-project wafer (MPW) multiplexer. It maps external pad lines to the internal chip ports.
* **`snake_top`**: The structural root module. It handles high-speed clock division, instantiates the input conditioning synchronizers, and houses the combinational binary-to-BCD score conversion logic.
* **`game_core`**: The central execution engine. It contains the master Finite State Machine (FSM), the sequential register shift matrix for the body tracking, coordinate generation logic, and the quadrant-based spatial framebuffer mapper.
* **`spi_driver`**: A serialization engine that translates the parallel commands from the core framebuffer into a single-bit synchronous SPI data stream.
* **`seven_seg`**: A dual-instance combinational lookup-table decoder that maps the BCD score to external 7-segment character displays.

---

## Physical Pad Frame Interface (Pinout Mapping)

### Primary Inputs (`ui_in`) & Control
| Physical Pin | Signal Name | Type | Description |
| :--- | :--- | :---: | :--- |
| `clk` | `CLOCK_50` | Input | Master System Clock (50 MHz) |
| `rst_n` | `reset_n` | Input | Global Asynchronous Reset (Active-Low) |
| `ui_in[0]` | `KEY[0]` | Input | Move Vector: Left (Active-Low, Debounced) |
| `ui_in[1]` | `KEY[1]` | Input | Move Vector: Right (Active-Low, Debounced) |
| `ui_in[2]` | `KEY[2]` | Input | Move Vector: Down (Active-Low, Debounced) |
| `ui_in[3]` | `KEY[3]` | Input | Move Vector: Up (Active-Low, Debounced) |

### Primary Outputs (`uo_out`) & Serial Peripherals
| Physical Pin | Signal Name | Type | Description |
| :--- | :--- | :---: | :--- |
| `uo_out[0]` | `MAX_DIN` | Output | Serial Peripheral Interface (SPI) Data Line |
| `uo_out[1]` | `MAX_CLK` | Output | Serial Peripheral Interface (SPI) Clock Domain (`slow_clk`) |
| `uo_out[2]` | `MAX_CS` | Output | Serial Peripheral Interface (SPI) Latch / Chip Select |
| `uo_out[3]` | `HEX0[0]` | Output | Seven-Segment Segment A (Units Digit) |
| `uo_out[4]` | `HEX0[1]` | Output | Seven-Segment Segment B (Units Digit) |
| `uo_out[5]` | `HEX0[2]` | Output | Seven-Segment Segment C (Units Digit) |
| `uo_out[6]` | `HEX0[3]` | Output | Seven-Segment Segment D (Units Digit) |
| `uo_out[7]` | `HEX0[4]` | Output | Seven-Segment Segment E (Units Digit) |

### Bidirectional Buses (`uio_out`) Mapped as Outputs
| Physical Pin | Signal Name | Type | Description |
| :--- | :--- | :---: | :--- |
| `uio_out[0]` | `HEX1[0]` | Output | Seven-Segment Segment A (Tens Digit) |
| `uio_out[1]` | `HEX1[1]` | Output | Seven-Segment Segment B (Tens Digit) |
| `uio_out[2]` | `HEX1[2]` | Output | Seven-Segment Segment C (Tens Digit) |
| `uio_out[3]` | `HEX1[3]` | Output | Seven-Segment Segment D (Tens Digit) |
| `uio_out[4]` | `HEX1[4]` | Output | Seven-Segment Segment E (Tens Digit) |
| `uio_out[5]` | `HEX1[5]` | Output | Seven-Segment Segment F (Tens Digit) |
| `uio_out[6]` | `HEX1[6]` | Output | Seven-Segment Segment G (Tens Digit) |

---

## Deep-Dive Implementation Details

### 1. Finite State Machine & Memory Arrays (`game_core.v`)
The core processing is handled by a single-bit dual-state master synchronous FSM containing `STATE_PLAY (1'b0)` and `STATE_GAMEOVER (1'b1)`.

* **Shift Register Body Tracking**: The physical structure of the snake is allocated as a static register file consisting of 12 stages of 4-bit coordinate vectors for both axes (`body_x` and `body_y`). Upon the assertion of a `game_tick`, an arithmetic downstream shift operation is executed: $\text{body}[i] \leftarrow \text{body}[i-1]$, and the new head coordinates (`h_x`, `h_y`) are appended based on the direction matrix.
* **Combinational Hazard Evaluation**: Collision metrics operate purely in the combinational space. Self-collision is verified by continuous loop evaluation matching head coordinates against active index segments. Boundary wall parameters are processed by tracking look-ahead limits relative to the 2-bit direction token.
* **Dynamic Hazards & Blinking Logic**: When the score reaches $\ge 5$, a toxic obstacle (`p_x`, `p_y`) is introduced into the memory registers. Bit 22 of a free-running register (`blink_counter`) is mapped to modulate the visibility bitstream of the obstacle to implement hardware-level parpadeo. A 28-bit internal counter resets and relocates the poison coordinates automatically every 4.5 seconds if left unconsumed.

### 2. Quadrant Multiplexing & Bus Serialization (`spi_driver.v`)
To display a continuous $16 \times 16$ board across a $2 \times 2$ grid of $8 \times 8$ matrices, the system utilizes quadrant-based structural multiplexing.

As the `spi_driver` updates the active row index (`cmd_index`), the core combinational blocks extract data from the spatial coordinates and assemble four independent 8-bit row words (`row_TL`, `row_TR`, `row_BL`, `row_BR`). Because the physical MAX7219 devices are wired in series, these four segments are packed into a single 64-bit multi-matrix word:

```verilog
dynamic_command = { {8'h01, row_BL}, {8'h01, row_BR}, {8'h01, row_TL}, {8'h01, row_TR} };
```
## Detailed Module Breakdown

### 1. Root Architecture: `snake_top.v`
This is the main structural file that connects the entire chip together. Think of it as a central hub or a motherboard. Its first job is to clean up the signals coming from the physical buttons using an internal counter; this prevents mechanical noise (button bouncing) from executing unintended movements. Second, it splits the fast 50 MHz main clock down to a much slower 5 kHz clock domain so the external LED matrices can read the data reliably. Finally, it checks the player's movement direction to make sure the snake cannot instantly reverse into itself (e.g., blocking a left turn if moving right) and converts the binary score into independent digits for the screen.

```verilog
// Preventing illegal 180-degree directional turns
always @(posedge CLOCK_50) begin
    if (!clean_sw0) begin
        dir <= 2'b00; 
    end else begin
        if (!clean_key1 && (dir != 2'b01))      dir <= 2'b00; // Move Right
        else if (!clean_key0 && (dir != 2'b00)) dir <= 2'b01; // Move Left
        else if (!clean_key3 && (dir != 2'b11)) dir <= 2'b10; // Move Up
        else if (!clean_key2 && (dir != 2'b10)) dir <= 2'b11; // Move Down
    end
end
```
### 2. Game Logic Engine: ` game_core.v`
This module acts as the "brain" of the chip. It manages the current state of the game (whether you are actively playing or hit a wall) and remembers the exact coordinates of the snake's head and its body segments using small memory registers. Every time a game update happens, it shifts the body coordinates down the line to simulate movement. It also constantly checks if the head coordinates overlap with the walls or the snake's own body to trigger a game-over. To generate targets (food and blinking poison blocks) in unpredictable spots, it tracks a continuously running counter that samples a position whenever an item is eaten.

```verilog
// Moving the snake body segments downstream sequentially
if (game_tick) begin
    for(b_i = 11; b_i > 0; b_i = b_i - 1) begin
        body_x[b_i] <= body_x[b_i-1];
        body_y[b_i] <= body_y[b_i-1];
    end
    body_x[0] <= h_x;
    body_y[0] <= h_y;
    
    // Updating head position based on current direction vector
    case(dir)
        2'b00: h_x <= h_x + 1'b1; 
        2'b01: h_x <= h_x - 1'b1; 
        2'b10: h_y <= h_y - 1'b1; 
        2'b11: h_y <= h_y + 1'b1; 
    endcase
end
```
### 3. Display Interface Driver: ` spi_driver.v`
Since the chip has a very limited number of physical output pins, we cannot wire every single LED matrix pixel directly to the hardware. Instead, this module acts as a translator that sends image data using the serial SPI protocol. It takes a large 64-bit parallel block of pixel data from the game core and utilizes a state machine to shift it out bit-by-bit over a single wire (MAX_DIN). It pulses a serial clock line (MAX_CLK) to tell the external screens to accept each bit, and flips a control pin (MAX_CS) to refresh all four LED matrices at the exact same time once a full row update is finished.

```verilog
// SPI State Machine bit-shifting loop
1: begin
    din_reg <= shift_reg[63]; // Place the highest bit on the data wire
    state   <= 2;
end
2: begin
    state   <= 3;
end
3: begin
    clk_reg <= 1;             // Pulse clock high to lock in the bit
    state   <= 4;
end
4: begin
    clk_reg   <= 0;           // Pull clock low and shift register left
    shift_reg <= shift_reg << 1;
    bit_count <= bit_count - 1;
    if(bit_count == 1) state <= 5; // Move to latch state if finished
    else               state <= 1; // Repeat for next bit
end
```
### 4. Score Character Decoder: ` seven_seg.v`
This is a small, straightforward helper module that handles the math for the score displays. It is completely combinational, meaning it has no memory and does not use a clock signal. It acts like a simple lookup table: you feed it a 4-bit binary number representing the score (from 0 to 9), and it instantly outputs the correct 7-bit patterns required to light up the matching segments on a standard digital display.

```verilog
// Binary-to-7-Segment illumination lookup table
always @(*) begin
    case(num)
        4'h0: seg = 7'b1000000; // Display 0
        4'h1: seg = 7'b1111001; // Display 1
        4'h2: seg = 7'b0100100; // Display 2
        4'h3: seg = 7'b0110000; // Display 3
        4'h4: seg = 7'b0011001; // Display 4
        4'h5: seg = 7'b0010010; // Display 5
        4'h6: seg = 7'b0000010; // Display 6
        4'h7: seg = 7'b1111000; // Display 7
        4'h8: seg = 7'b0000000; // Display 8
        4'h9: seg = 7'b0010000; // Display 9
        default: seg = 7'b1111111; // Turn completely off
    endcase
end
```
## Hardware Verification on FPGA

To validate the RTL architecture before target fabrication, the design was fully synthesized and tested on a physical **Intel/Altera Cyclone II (EP2C20F484C7)** FPGA development platform. The hardware twin setup successfully verified the core processing cycles, peripheral timings, and overall user interactivity in real-time.

### 1. Matrix Peripheral Pin Out & Connectivity
The display infrastructure consists of four cascaded MAX7219 $8 \times 8$ LED dot matrices configured in a daisy-chain chain array to form the $16 \times 16$ active gaming grid. The serial interface between the FPGA board pins and the peripheral module uses the following wiring layout:

<img width="1071" height="737" alt="MAX7219" src="https://github.com/user-attachments/assets/ca7f16c0-bb51-4213-a8c9-705461763a76" />

* **VCC**: Wired to the FPGA 5V power rail.
* **GND**: Tied to the common system ground.
* **DIN (Data In)**: Connected to the `MAX_DIN` output pin. It receives the serialized 64-bit row packets bit-by-bit.
* **CS/LOAD (Chip Select)**: Connected to the `MAX_CS` latch pin. It pulses high to tell all four matrices to load the shifting registers simultaneously.
* **CLK (Serial Clock)**: Connected to the `MAX_CLK` pin driven by the 5 kHz internal `slow_clk` clock domain.
---
### 2. Collision Mechanics & Full-Screen Flash
The boundary collision and self-eating logic were verified using 4 onboard mechanical push-buttons (`KEY[3:0]`). When the tracking system captures a collision event—such as the snake head coordinate meeting a wall boundary ($0$ or $15$) or crossing path coordinates with its own body register file—the FSM immediately switches the game state to `STATE_GAMEOVER`. 

<img width="4018" height="2296" alt="snake1" src="https://github.com/user-attachments/assets/9f0fa0b1-d732-4400-bbd4-902d967670b2" />

<img width="3904" height="1955" alt="collision" src="https://github.com/user-attachments/assets/b490c132-174b-40bb-af61-77acf49b15d7" />

To give the player clear visual feedback, the combinational block automatically overrides the standard pixel coordinates and sends a hardcoded hex command (`8'hFF`) to every row on the grid. This triggers an instantaneous, highly visible **full-screen flash** turning on all 256 LEDs simultaneously.

```verilog
// Flash all pixels high when the game over state triggers
if (game_over) begin
    row_TL = 8'hFF; row_TR = 8'hFF;
    row_BL = 8'hFF; row_BR = 8'hFF;
end
```
3. Food Dynamics & Poison Hazard Validation
The gameplay mechanics were tested to ensure the item distribution logic behaves as intended without trapping or locking hazards:

Food: Whenever the snake head coordinates match the target food register coordinates (f_x == h_x and f_y == h_y), the chip instantly increments the snake_len tracking register by 1, calculates the updated score display, and samples the free-running high-speed counter to teleport the next food piece to a random unassigned space.

<img width="3900" height="2014" alt="food" src="https://github.com/user-attachments/assets/acf9c01a-656d-4677-8a28-e8851fdce7f2" />

Poison Obstacles: The dynamic hazard engine was verified to unlock only after the score is higher or equal to 5. The poison block utilizes a dedicated internal timer block to blink continuously, separating it visually from standard food items. If the player consumes the poison, the score tracker safely subtracts 2 length segments from the body register array. If the poison is ignored, it automatically relocates to a new coordinate after 4.5 seconds to keep the game board dynamically shifting.

## FPGA Implementation Operation





