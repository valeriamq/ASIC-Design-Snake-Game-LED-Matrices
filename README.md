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

