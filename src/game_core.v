module game_core(
    input clk_50,
    input reset_n,
    input [1:0] dir,
    input [3:0] cmd_index,
    output reg game_over,
    output reg [4:0] snake_len, 
    output reg [63:0] dynamic_command
);

    localparam STATE_PLAY     = 1'b0;
    localparam STATE_GAMEOVER = 1'b1;
    reg current_state;

    reg [27:0] restart_counter; 
    reg [23:0] tick_counter;
    reg game_tick;
    reg [27:0] poison_move_counter;
    reg poison_active;

    // Posiciones de juego
    reg [3:0] h_x, h_y; 
    reg [3:0] f_x, f_y; 
    reg [3:0] p_x, p_y; 
    
    // Cuerpo de la serpiente (Optimizado a 8 bloques para Tiny Tapeout)
    reg [3:0] body_x [0:7];
    reg [3:0] body_y [0:7];

    // --- GENERADOR ALEATORIO ULTRA SIMPLE ---
    reg [3:0] rand_x;
    reg [3:0] rand_y;
    always @(posedge clk_50) begin
        if (!reset_n) begin
            rand_x <= 4'd2;
            rand_y <= 4'd5;
        end else begin
            rand_x <= rand_x + 1'b1;
            if (rand_x == 4'd15) rand_y <= rand_y + 1'b1;
        end
    end

    // Colisiones
    reg self_collision;
    reg wall_collision;
    wire eaten = (h_x == f_x) && (h_y == f_y);
    wire eaten_poison = poison_active && (h_x == p_x && h_y == p_y);
    wire collision_detected = self_collision || wall_collision;

    integer m;
    always @(*) begin
        self_collision = 1'b0;
        for (m = 0; m < 8; m = m + 1) begin
            if (m < (snake_len - 5'd1)) begin
                if (h_x == body_x[m] && h_y == body_y[m]) self_collision = 1'b1;
            end
        end

        wall_collision = 1'b0;
        if ((h_x == 4'd15 && dir == 2'b00) && game_tick)      wall_collision = 1'b1;
        else if ((h_x == 4'd0  && dir == 2'b01) && game_tick) wall_collision = 1'b1;
        else if ((h_y == 4'd0  && dir == 2'b10) && game_tick) wall_collision = 1'b1;
        else if ((h_y == 4'd15 && dir == 2'b11) && game_tick) wall_collision = 1'b1;
    end

    // --- MATRICES PLANAS (Registros directos en lugar de arrays de memoria) ---
    // Esto elimina los operadores $shl dinámicos que cuelgan a Yosys
    reg [63:0] flat_TL;
    reg [63:0] flat_TR;
    reg [63:0] flat_BL;
    reg [63:0] flat_BR;
    
    reg [22:0] blink_counter;
    wire poison_visible = blink_counter[22];

    integer b_i;

    // BLOQUE PRINCIPAL SECUENCIAL
    always @(posedge clk_50) begin
        if (!reset_n) begin
            blink_counter        <= 0;
            current_state        <= STATE_PLAY;
            restart_counter      <= 0;
            tick_counter         <= 0;
            poison_move_counter  <= 0;
            poison_active        <= 1'b0;
            game_tick            <= 0;
            game_over            <= 1'b0;
            
            h_x       <= 4'd3;  h_y       <= 4'd3;
            body_x[0] <= 4'd2;  body_y[0] <= 4'd3;
            for(b_i=1; b_i<8; b_i=b_i+1) begin
                body_x[b_i] <= 4'd0; body_y[b_i] <= 4'd0;
            end

            f_x <= 4'd10; f_y <= 4'd4; 
            p_x <= 4'd2;  p_y <= 4'd12;
            snake_len <= 5'd2;
            flat_TL <= 64'b0; flat_TR <= 64'b0; flat_BL <= 64'b0; flat_BR <= 64'b0;

        end else begin
            blink_counter <= blink_counter + 1'b1;

            case (current_state)
                STATE_PLAY: begin
                    game_over <= 1'b0;
                    if (snake_len >= 5'd4) poison_active <= 1'b1;

                    if (tick_counter == 24'd12_500_000) begin 
                        tick_counter <= 0;
                        game_tick    <= 1'b1;
                    end else begin
                        tick_counter <= tick_counter + 1'b1;
                        game_tick    <= 1'b0;
                    end

                    if (collision_detected) begin
                        current_state <= STATE_GAMEOVER;
                    end else if (game_tick) begin
                        for(b_i=7; b_i>0; b_i=b_i-1) begin
                            body_x[b_i] <= body_x[b_i-1];
                            body_y[b_i] <= body_y[b_i-1];
                        end
                        body_x[0] <= h_x;
                        body_y[0] <= h_y;

                        case(dir)
                            2'b00: h_x <= h_x + 1'b1; 
                            2'b01: h_x <= h_x - 1'b1; 
                            2'b10: h_y <= h_y - 1'b1; 
                            2'b11: h_y <= h_y + 1'b1; 
                        endcase
                    end

                    if (eaten) begin
                        f_x <= rand_x; 
                        f_y <= rand_y; 
                        if (snake_len < 5'd8) snake_len <= snake_len + 1'b1; 
                    end else if (eaten_poison) begin
                        if (snake_len < 5'd4) current_state <= STATE_GAMEOVER;
                        else begin
                            snake_len <= snake_len - 5'd2; 
                            p_x <= rand_y; 
                            p_y <= rand_x;
                            poison_move_counter <= 0;
                        end
                    end else if (poison_active) begin
                        if (poison_move_counter >= 28'd225_000_000) begin
                            poison_move_counter <= 0;
                            p_x <= rand_y; 
                            p_y <= rand_x;
                        end else begin
                            poison_move_counter <= poison_move_counter + 1'b1;
                        end
                    end
                end

                STATE_GAMEOVER: begin
                    game_over <= 1'b1;
                    if (restart_counter == 28'd150_000_000) begin
                        restart_counter <= 0;
                        current_state   <= STATE_PLAY;
                        h_x <= 4'd3; h_y <= 4'd3;
                        body_x[0] <= 4'd2; body_y[0] <= 4'd3;
                        for(b_i=1; b_i<8; b_i=b_i+1) begin
                            body_x[b_i] <= 4'd0; body_y[b_i] <= 4'd0;
                        end
                        f_x <= 4'd10; f_y <= 4'd4;
                        p_x <= 4'd2;  p_y <= 4'd12;
                        snake_len <= 5'd2;
                        poison_active <= 1'b0;
                    end else begin
                        restart_counter <= restart_counter + 1'b1;
                    end
                end
            endcase

            // --- RENDERIZADO DIRECTO A REGISTROS PLANOS ---
            if (game_over) begin
                flat_TL <= {64{1'b1}}; flat_TR <= {64{1'b1}};
                flat_BL <= {64{1'b1}}; flat_BR <= {64{1'b1}};
            end else begin
                flat_TL <= 64'b0; flat_TR <= 64'b0;
                flat_BL <= 64'b0; flat_BR <= 64'b0;

                // Dibujar Cabeza
                if (h_y < 4'd8) begin
                    if (h_x < 4'd8) flat_TL[{h_y[2:0], 3'd7 - h_x[2:0]}] <= 1'b1;
                    else            flat_TR[{h_y[2:0], 3'd7 - h_x[2:0]}] <= 1'b1;
                end else begin
                    if (h_x < 4'd8) flat_BL[{h_y[2:0], 3'd7 - h_x[2:0]}] <= 1'b1;
                    else            flat_BR[{h_y[2:0], 3'd7 - h_x[2:0]}] <= 1'b1;
                end

                // Dibujar Cuerpo
                for(b_i=0; b_i<8; b_i=b_i+1) begin
                    if (b_i < (snake_len - 5'd1)) begin
                        if (body_y[b_i] < 4'd8) begin
                            if (body_x[b_i] < 4'd8) flat_TL[{body_y[b_i][2:0], 3'd7 - body_x[b_i][2:0]}] <= 1'b1;
                            else                    flat_TR[{body_y[b_i][2:0], 3'd7 - body_x[b_i][2:0]}] <= 1'b1;
                        end else begin
                            if (body_x[b_i] < 4'd8) flat_BL[{body_y[b_i][2:0], 3'd7 - body_x[b_i][2:0]}] <= 1'b1;
                            else                    flat_BR[{body_y[b_i][2:0], 3'd7 - body_x[b_i][2:0]}] <= 1'b1;
                        end
                    end
                end

                // Dibujar Comida
                if (f_y < 4'd8) begin
                    if (f_x < 4'd8) flat_TL[{f_y[2:0], 3'd7 - f_x[2:0]}] <= 1'b1;
                    else            flat_TR[{f_y[2:0], 3'd7 - f_x[2:0]}] <= 1'b1;
                end else begin
                    if (f_x < 4'd8) flat_BL[{f_y[2:0], 3'd7 - f_x[2:0]}] <= 1'b1;
                    else            flat_BR[{f_y[2:0], 3'd7 - f_x[2:0]}] <= 1'b1;
                end

                // Dibujar Veneno
                if (poison_active && poison_visible) begin
                    if (p_y < 4'd8) begin
                        if (p_x < 4'd8) flat_TL[{p_y[2:0], 3'd7 - p_x[2:0]}] <= 1'b1;
                        else            flat_TR[{p_y[2:0], 3'd7 - p_x[2:0]}] <= 1'b1;
                    end else begin
                        if (p_x < 4'd8) flat_BL[{p_y[2:0], 3'd7 - p_x[2:0]}] <= 1'b1;
                        else            flat_BR[{p_y[2:0], 3'd7 - p_x[2:0]}] <= 1'b1;
                    end
                end
            end
        end
    end

    // --- MAPEO SPI COMBINACIONAL TOTALMENTE PLANO (Ultra rápido) ---
    always @(*) begin
        case(cmd_index)
            4'd0: dynamic_command = {16'h0900, 16'h0900, 16'h0900, 16'h0900};
            4'd1: dynamic_command = {16'h0A02, 16'h0A02, 16'h0A02, 16'h0A02};
            4'd2: dynamic_command = {16'h0B07, 16'h0B07, 16'h0B07, 16'h0B07};
            4'd3: dynamic_command = {16'h0C01, 16'h0C01, 16'h0C01, 16'h0C01};
            4'h4: dynamic_command = {16'h0F00, 16'h0F00, 16'h0F00, 16'h0F00};
            
            // Accedemos a rebanadas de bits fijas, lo que elimina la optimización de recursos pesados
            4'd5:  dynamic_command = { {8'h01, flat_BL[7:0]},   {8'h01, flat_BR[7:0]},   {8'h01, flat_TL[7:0]},   {8'h01, flat_TR[7:0]} };
            4'd6:  dynamic_command = { {8'h02, flat_BL[15:8]},  {8'h02, flat_BR[15:8]},  {8'h02, flat_TL[15:8]},  {8'h02, flat_TR[15:8]} };
            4'd7:  dynamic_command = { {8'h03, flat_BL[23:16]}, {8'h03, flat_BR[23:16]}, {8'h03, flat_TL[23:16]}, {8'h03, flat_TR[23:16]} };
            4'd8:  dynamic_command = { {8'h04, flat_BL[31:24]}, {8'h04, flat_BR[31:24]}, {8'h04, flat_TL[31:24]}, {8'h04, flat_TR[31:24]} };
            4'd9:  dynamic_command = { {8'h05, flat_BL[39:32]}, {8'h05, flat_BR[39:32]}, {8'h05, flat_TL[39:32]}, {8'h05, flat_TR[39:32]} };
            4'd10: dynamic_command = { {8'h06, flat_BL[47:40]}, {8'h06, flat_BR[47:40]}, {8'h06, flat_TL[47:40]}, {8'h06, flat_TR[47:40]} };
            4'd11: dynamic_command = { {8'h07, flat_BL[55:48]}, {8'h07, flat_BR[55:48]}, {8'h07, flat_TL[55:48]}, {8'h07, flat_TR[55:48]} };
            4'd12: dynamic_command = { {8'h08, flat_BL[63:56]}, {8'h08, flat_BR[63:56]}, {8'h08, flat_TL[63:56]}, {8'h08, flat_TR[63:56]} };
            default: dynamic_command = 64'b0;
        endcase
    end

endmodule