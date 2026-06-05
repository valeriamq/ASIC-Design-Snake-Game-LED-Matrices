/*
 * Copyright (c) 2026 Tu Nombre
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  wire [6:0] hex0_full;

  snake_top mi_juego (
      .CLOCK_50(clk),
      .SW(rst_n),
      
      .KEY(ui_in[3:0]),          
      
      .MAX_DIN(uo_out[0]),
      .MAX_CLK(uo_out[1]),
      .MAX_CS(uo_out[2]),
      
      .HEX0(hex0_full),
      .HEX1(uio_out[6:0])
    );

  assign uo_out[7:3] = hex0_full[4:0];

  assign uio_oe  = 8'b01111111;
  assign uio_out[7] = 1'b0;

  wire _unused = &{ena, ui_in[7:4], uio_in, hex0_full[6:5], 1'b0};

endmodule