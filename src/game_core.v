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

    // Tu mapa original completo de 16x16 (0 a 15)
    reg [3:0] h_x, h_y; 
    reg [3:0] f_x, f_y; 
    reg [3:0] p_x, p_y; 
    
    // Tu largo original de serpiente (12 bloques)
    reg [3:0] body_x [0:11];
    reg [3:0] body_y [0:11];

    // --- GENERADOR ALEATORIO ULTRA COMPACTO ---
    reg [3:0] rand_x;
    reg [3:0] rand_y;
    always @(posedge clk_50) begin
        if (!reset_n) begin
            rand_x <= 4'd4;
            rand_y <= 4'd9;
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
        for (m = 0; m < 12; m = m + 1) begin
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

    // --- VIDEO RAM (VRAM) PLANIFICADA EN SILICIO ---
    // Dividida estáticamente para las 4 esquinas de tu matriz 16x16
    reg [7:0] vram_TL [0:7];
    reg [7:0] vram_TR [0:7];
    reg [7:0] vram_BL [0:7];
    reg [7:0] vram_BR [0:7];

    reg [22:0] blink_counter;
    wire poison_visible = blink_counter[22];
    integer idx, r_idx;

    // LOGICA DE JUEGO Y ESCRITURA EN VRAM
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
            
            h_x       <= 4'd5;  h_y       <= 4'd5;
            body_x[0] <= 4'd4;  body_y[0] <= 4'd5;
            for(idx=1; idx<12; idx=idx+1) begin
                body_x[idx] <= 4'd0; body_y[idx] <= 4'd0;
            end

            f_x <= 4'd12; f_y <= 4'd4; 
            p_x <= 4'd2;  p_y <= 4'd12;
            snake_len <= 5'd2;

            for(r_idx=0; r_idx<8; r_idx=r_idx+1) begin
                vram_TL[r_idx] <= 8'h0; vram_TR[r_idx] <= 8'h0;
                vram_BL[r_idx] <= 8'h0; vram_BR[r_idx] <= 8'h0;
            end

        end else begin
            blink_counter <= blink_counter + 1'b1;

            case (current_state)
                STATE_PLAY: begin
                    game_over <= 1'b0;
                    if (snake_len >= 5'd5) poison_active <= 1'b1;

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
                        for(idx=11; idx>0; idx=idx-1) begin
                            body_x[idx] <= body_x[idx-1];
                            body_y[idx] <= body_y[idx-1];
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
                        if (snake_len < 5'd12) snake_len <= snake_len + 1'b1; 
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
                        h_x <= 4'd5; h_y <= 4'd5;
                        body_x[0] <= 4'd4; body_y[0] <= 4'd5;
                        for(idx=1; idx<12; idx=idx+1) begin
                            body_x[idx] <= 4'd0; body_y[idx] <= 4'd0;
                        end
                        f_x <= 4'd12; f_y <= 4'd4;
                        p_x <= 4'd2;  p_y <= 4'd12;
                        snake_len <= 5'd2;
                        poison_active <= 1'b0;
                    end else begin
                        restart_counter <= restart_counter + 1'b1;
                    end
                end
            endcase

            // --- ESCRIBIENDO EN LA VRAM POR CICLO (Ruteado Limpio) ---
            if (game_over) begin
                for(r_idx=0; r_idx<8; r_idx=r_idx+1) begin
                    vram_TL[r_idx] <= 8'hFF; vram_TR[r_idx] <= 8'hFF;
                    vram_BL[r_idx] <= 8'hFF; vram_BR[r_idx] <= 8'hFF;
                end
            end else begin
                // Limpiar pantalla vieja
                for(r_idx=0; r_idx<8; r_idx=r_idx+1) begin
                    vram_TL[r_idx] <= 8'h0; vram_TR[r_idx] <= 8'h0;
                    vram_BL[r_idx] <= 8'h0; vram_BR[r_idx] <= 8'h0;
                end

                // Pintar Cabeza
                if (h_y < 4'd8) begin
                    if (h_x < 4'd8) vram_TL[h_y[2:0]][3'd7 - h_x[2:0]] <= 1'b1;
                    else            vram_TR[h_y[2:0]][3'd7 - h_x[2:0]] <= 1'b1;
                end else begin
                    if (h_x < 4'd8) vram_BL[h_y[2:0]][3'd7 - h_x[2:0]] <= 1'b1;
                    else            vram_BR[h_y[2:0]][3'd7 - h_x[2:0]] <= 1'b1;
                end

                // Pintar Cuerpo
                for(idx=0; idx<12; idx=idx+1) begin
                    if (idx < (snake_len - 5'd1)) begin
                        if (body_y[idx] < 4'd8) begin
                            if (body_x[idx] < 4'd8) vram_TL[body_y[idx][2:0]][3'd7 - body_x[idx][2:0]] <= 1'b1;
                            else                    vram_TR[body_y[idx][2:0]][3'd7 - body_x[idx][2:0]] <= 1'b1;
                        end else begin
                            if (body_x[idx] < 4'd8) vram_BL[body_y[idx][2:0]][3'd7 - body_x[idx][2:0]] <= 1'b1;
                            else                    vram_BR[body_y[idx][2:0]][3'd7 - body_x[idx][2:0]] <= 1'b1;
                        end
                    end
                end

                // Pintar Comida
                if (f_y < 4'd8) begin
                    if (f_x < 4'd8) vram_TL[f_y[2:0]][3'd7 - f_x[2:0]] <= 1'b1;
                    else            vram_TR[f_y[2:0]][3'd7 - f_x[2:0]] <= 1'b1;
                end else begin
                    if (f_x < 4'd8) vram_BL[f_y[2:0]][3'd7 - f_x[2:0]] <= 1'b1;
                    else            vram_BR[f_y[2:0]][3'd7 - f_x[2:0]] <= 1'b1;
                end

                // Pintar Veneno
                if (poison_active && poison_visible) begin
                    if (p_y < 4'd8) begin
                        if (p_x < 4'd8) vram_TL[p_y[2:0]][3'd7 - p_x[2:0]] <= 1'b1;
                        else            vram_TR[p_y[2:0]][3'd7 - p_x[2:0]] <= 1'b1;
                    end else begin
                        if (p_x < 4'd8) vram_BL[p_y[2:0]][3'd7 - p_x[2:0]] <= 1'b1;
                        else            vram_BR[p_y[2:0]][3'd7 - p_x[2:0]] <= 1'b1;
                    end
                end
            end
        end
    end

    // --- SALIDA SPI LEYENDO DE VRAM (Cero lógica cruzada) ---
    // Esto es un multiplexor puro y directo. OpenROAD lo enrutará sin esfuerzo.
    always @(*) begin
        case(cmd_index)
            4'd0: dynamic_command = {16'h0900, 16'h0900, 16'h0900, 16'h0900};
            4'd1: dynamic_command = {16'h0A02, 16'h0A02, 16'h0A02, 16'h0A02};
            4'd2: dynamic_command = {16'h0B07, 16'h0B07, 16'h0B07, 16'h0B07};
            4'd3: dynamic_command = {16'h0C01, 16'h0C01, 16'h0C01, 16'h0C01};
            4'h4: dynamic_command = {16'h0F00, 16'h0F00, 16'h0F00, 16'h0F00};
            
            4'd5:  dynamic_command = { {8'h01, vram_BL[0]}, {8'h01, vram_BR[0]}, {8'h01, vram_TL[0]}, {8'h01, vram_TR[0]} };
            4'd6:  dynamic_command = { {8'h02, vram_BL[1]}, {8'h02, vram_BR[1]}, {8'h02, vram_TL[1]}, {8'h02, vram_TR[1]} };
            4'd7:  dynamic_command = { {8'h03, vram_BL[2]}, {8'h03, vram_BR[2]}, {8'h03, vram_TL[2]}, {8'h03, vram_TR[2]} };
            4'd8:  dynamic_command = { {8'h04, vram_BL[3]}, {8'h04, vram_BR[3]}, {8'h04, vram_TL[3]}, {8'h04, vram_TR[3]} };
            4'd9:  dynamic_command = { {8'h05, vram_BL[4]}, {8'h05, vram_BR[4]}, {8'h05, vram_TL[4]}, {8'h05, vram_TR[4]} };
            4'd10: dynamic_command = { {8'h06, vram_BL[5]}, {8'h06, vram_BR[5]}, {8'h06, vram_TL[5]}, {8'h06, vram_TR[5]} };
            4'd11: dynamic_command = { {8'h07, vram_BL[6]}, {8'h07, vram_BR[6]}, {8'h07, vram_TL[6]}, {8'h07, vram_TR[6]} };
            4'd12: dynamic_command = { {8'h08, vram_BL[7]}, {8'h08, vram_BR[7]}, {8'h08, vram_TL[7]}, {8'h08, vram_TR[7]} };
            default: dynamic_command = 64'b0;
        endcase
    end

endmodule