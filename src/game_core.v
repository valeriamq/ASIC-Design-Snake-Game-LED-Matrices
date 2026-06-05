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

    // Contador para que el veneno cambie solo de posición
    reg [27:0] poison_move_counter;

    // El veneno ahora es un registro (memoria) para que sea permanente
    reg poison_active;

    // Posiciones
    reg [3:0] h_x, h_y; 
    reg [3:0] f_x, f_y; 
    reg [3:0] p_x, p_y; 
    
    // Memoria del cuerpo expandida a 30 bloques
    reg [3:0] body_x [0:29];
    reg [3:0] body_y [0:29];

    // --- GENERADOR DE POSICIONES ALEATORIAS (50 MHz) ---
    reg [3:0] rand_x;
    reg [3:0] rand_y;
    
    always @(posedge clk_50) begin
        if (!reset_n) begin
            rand_x <= 4'd4;
            rand_y <= 4'd4;
        end else begin
            if (rand_x >= 4'd11) rand_x <= 4'd4;
            else rand_x <= rand_x + 1'b1;

            if (rand_x == 4'd11) begin
                if (rand_y >= 4'd11) rand_y <= 4'd4;
                else rand_y <= rand_y + 1'b1;
            end
        end
    end

    // Alertas combinacionales
    reg self_collision;
    reg wall_collision;
    
    // Identificadores de colisión con comida y veneno
    wire eaten = (h_x == f_x) && (h_y == f_y);
    wire eaten_poison = poison_active && (h_x == p_x && h_y == p_y);
    
    wire collision_detected = self_collision || wall_collision;

    // Índices de bucles dimensionados correctamente para evitar alertas linter
    reg [4:0] m;
    // reg [4:0] k; // Comentado para eliminar la advertencia UNUSEDSIGNAL
    reg [3:0] r;
    reg [4:0] b;

    // Detección de colisiones
    always @(*) begin
        self_collision = 1'b0;
        for (m = 5'd0; m < 5'd30; m = m + 5'd1) begin
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

    // BLOQUE PRINCIPAL
    always @(posedge clk_50) begin
        if (!reset_n) begin
            current_state        <= STATE_PLAY;
            restart_counter      <= 0;
            tick_counter         <= 0;
            poison_move_counter  <= 0;
            poison_active        <= 1'b0;
            game_tick            <= 0;
            game_over            <= 1'b0;
            
            h_x       <= rand_x;  
            h_y       <= rand_y;
            body_x[0] <= rand_x - 1'b1;  
            body_y[0] <= rand_y;
            
            body_x[1]  <= 4'd0; body_y[1]  <= 4'd0; body_x[2]  <= 4'd0; body_y[2]  <= 4'd0;
            body_x[3]  <= 4'd0; body_y[3]  <= 4'd0; body_x[4]  <= 4'd0; body_y[4]  <= 4'd0;
            body_x[5]  <= 4'd0; body_y[5]  <= 4'd0; body_x[6]  <= 4'd0; body_y[6]  <= 4'd0;
            body_x[7]  <= 4'd0; body_y[7]  <= 4'd0; body_x[8]  <= 4'd0; body_y[8]  <= 4'd0;
            body_x[9]  <= 4'd0; body_y[9]  <= 4'd0; body_x[10] <= 4'd0; body_y[10] <= 4'd0;
            body_x[11] <= 4'd0; body_y[11] <= 4'd0; body_x[12] <= 4'd0; body_y[12] <= 4'd0;
            body_x[13] <= 4'd0; body_y[13] <= 4'd0; body_x[14] <= 4'd0; body_y[14] <= 4'd0;
            body_x[15] <= 4'd0; body_y[15] <= 4'd0; body_x[16] <= 4'd0; body_y[16] <= 4'd0;
            body_x[17] <= 4'd0; body_y[17] <= 4'd0; body_x[18] <= 4'd0; body_y[18] <= 4'd0;
            body_x[19] <= 4'd0; body_y[19] <= 4'd0; body_x[20] <= 4'd0; body_y[20] <= 4'd0;
            body_x[21] <= 4'd0; body_y[21] <= 4'd0; body_x[22] <= 4'd0; body_y[22] <= 4'd0;
            body_x[23] <= 4'd0; body_y[23] <= 4'd0; body_x[24] <= 4'd0; body_y[24] <= 4'd0;
            body_x[25] <= 4'd0; body_y[25] <= 4'd0; body_x[26] <= 4'd0; body_y[26] <= 4'd0;
            body_x[27] <= 4'd0; body_y[27] <= 4'd0; body_x[28] <= 4'd0; body_y[28] <= 4'd0;
            body_x[29] <= 4'd0; body_y[29] <= 4'd0;

            f_x       <= 4'd12; f_y       <= 4'd4; 
            p_x       <= 4'd2;  p_y       <= 4'd12;
            snake_len <= 5'd2;
            
        end else begin
            case (current_state)
                STATE_PLAY: begin
                    game_over       <= 1'b0;
                    restart_counter <= 0;

                    if (snake_len >= 5'd6) begin
                        poison_active <= 1'b1;
                    end

                    if (tick_counter == 24'd12_500_000) begin 
                        tick_counter <= 0;
                        game_tick    <= 1'b1;
                    end else begin
                        tick_counter <= tick_counter + 1'b1;
                        game_tick    <= 1'b0;
                    end

                    if (collision_detected) begin
                        current_state <= STATE_GAMEOVER;
                    end
                    else if (game_tick) begin
                        body_x[29] <= body_x[28]; body_y[29] <= body_y[28];
                        body_x[28] <= body_x[27]; body_y[28] <= body_y[27];
                        body_x[27] <= body_x[26]; body_y[27] <= body_y[26];
                        body_x[26] <= body_x[25]; body_y[26] <= body_y[25];
                        body_x[25] <= body_x[24]; body_y[25] <= body_y[24];
                        body_x[24] <= body_x[23]; body_y[24] <= body_y[23];
                        body_x[23] <= body_x[22]; body_y[23] <= body_y[22];
                        body_x[22] <= body_x[21]; body_y[22] <= body_y[21];
                        body_x[21] <= body_x[20]; body_y[21] <= body_y[20];
                        body_x[20] <= body_x[19]; body_y[20] <= body_y[19];
                        body_x[19] <= body_x[18]; body_y[19] <= body_y[18];
                        body_x[18] <= body_x[17]; body_y[18] <= body_y[17];
                        body_x[17] <= body_x[16]; body_y[17] <= body_y[16];
                        body_x[16] <= body_x[15]; body_y[16] <= body_y[15];
                        body_x[15] <= body_x[14]; body_y[15] <= body_y[14];
                        body_x[14] <= body_x[13]; body_y[14] <= body_y[13];
                        body_x[13] <= body_x[12]; body_y[13] <= body_y[12];
                        body_x[12] <= body_x[11]; body_y[12] <= body_y[11];
                        body_x[11] <= body_x[10]; body_y[11] <= body_y[10];
                        body_x[10] <= body_x[9];  body_y[10] <= body_y[9];
                        body_x[9]  <= body_x[8];  body_y[9]  <= body_y[8];
                        body_x[8]  <= body_x[7];  body_y[8]  <= body_y[7];
                        body_x[7]  <= body_x[6];  body_y[7]  <= body_y[6];
                        body_x[6]  <= body_x[5];  body_y[6]  <= body_y[5];
                        body_x[5]  <= body_x[4];  body_y[5]  <= body_y[4];
                        body_x[4]  <= body_x[3];  body_y[4]  <= body_y[3];
                        body_x[3]  <= body_x[2];  body_y[3]  <= body_y[2];
                        body_x[2]  <= body_x[1];  body_y[2]  <= body_y[1];
                        body_x[1]  <= body_x[0];  body_y[1]  <= body_y[0];
                        
                        body_x[0] <= h_x;
                        body_y[0] <= h_y;

                        case(dir)
                            2'b00: h_x <= h_x + 1'b1; 
                            2'b01: h_x <= h_x - 1'b1; 
                            2'b10: h_y <= h_y - 1'b1; 
                            2'b11: h_y <= h_y + 1'b1; 
                        endcase
                    end

                    // Lógica de comida con sumas de 5 bits para evitar CMPCONST
                    if (eaten) begin
                        f_x <= ({1'b0, rand_x} + 5'd3 > 5'd15) ? 4'd2 : rand_x + 4'd3; 
                        f_y <= ({1'b0, rand_y} + 5'd5 > 5'd15) ? 4'd3 : rand_y + 4'd5; 
                        if (snake_len < 5'd31) snake_len <= snake_len + 1'b1; 
                    end
                    
                    // Lógica de Muerte por VENENO con sumas de 5 bits para evitar CMPCONST
                    else if (eaten_poison) begin
                        if (snake_len < 5'd4) begin
                            current_state <= STATE_GAMEOVER;
                        end else begin
                            snake_len <= snake_len - 5'd2; 
                            p_x <= ({1'b0, rand_y} + 5'd2 > 5'd14) ? 4'd1 : rand_y + 4'd2; 
                            p_y <= ({1'b0, rand_x} + 5'd1 > 5'd15) ? 4'd1 : rand_x + 4'd1;
                            poison_move_counter <= 0;
                        end
                    end 
                    // Movimiento automático del veneno (cada 4.5s) con sumas de 5 bits para evitar CMPCONST
                    else if (poison_active) begin
                        if (poison_move_counter >= 28'd225_000_000) begin
                            poison_move_counter <= 0;
                            p_x <= ({1'b0, rand_y} + 5'd3 > 5'd14) ? 4'd2 : rand_y + 4'd3; 
                            p_y <= ({1'b0, rand_x} + 5'd2 > 5'd15) ? 4'd1 : rand_x + 4'd2;
                        end else begin
                            poison_move_counter <= poison_move_counter + 1'b1;
                        end
                    end else begin
                        poison_move_counter <= 0;
                    end
                end

                STATE_GAMEOVER: begin
                    game_over <= 1'b1;
                    game_tick <= 1'b0;
                    
                    if (restart_counter == 28'd150_000_000) begin
                        restart_counter <= 0;
                        tick_counter    <= 0;
                        poison_move_counter <= 0;
                        poison_active   <= 1'b0; 
                        
                        h_x       <= rand_x;  
                        h_y       <= rand_y;
                        body_x[0] <= rand_x - 1'b1;  
                        body_y[0] <= rand_y;
                        
                        body_x[1]  <= 4'd0; body_y[1]  <= 4'd0; body_x[2]  <= 4'd0; body_y[2]  <= 4'd0;
                        body_x[3]  <= 4'd0; body_y[3]  <= 4'd0; body_x[4]  <= 4'd0; body_y[4]  <= 4'd0;
                        body_x[5]  <= 4'd0; body_y[5]  <= 4'd0; body_x[6]  <= 4'd0; body_y[6]  <= 4'd0;
                        body_x[7]  <= 4'd0; body_y[7]  <= 4'd0; body_x[8]  <= 4'd0; body_y[8]  <= 4'd0;
                        body_x[9]  <= 4'd0; body_y[9]  <= 4'd0; body_x[10] <= 4'd0; body_y[10] <= 4'd0;
                        body_x[11] <= 4'd0; body_y[11] <= 4'd0; body_x[12] <= 4'd0; body_y[12] <= 4'd0;
                        body_x[13] <= 4'd0; body_y[13] <= 4'd0; body_x[14] <= 4'd0; body_y[14] <= 4'd0;
                        body_x[15] <= 4'd0; body_y[15] <= 4'd0; body_x[16] <= 4'd0; body_y[16] <= 4'd0;
                        body_x[17] <= 4'd0; body_y[17] <= 4'd0; body_x[18] <= 4'd0; body_y[18] <= 4'd0;
                        body_x[19] <= 4'd0; body_y[19] <= 4'd0; body_x[20] <= 4'd0; body_y[20] <= 4'd0;
                        body_x[21] <= 4'd0; body_y[21] <= 4'd0; body_x[22] <= 4'd0; body_y[22] <= 4'd0;
                        body_x[23] <= 4'd0; body_y[23] <= 4'd0; body_x[24] <= 4'd0; body_y[24] <= 4'd0;
                        body_x[25] <= 4'd0; body_y[25] <= 4'd0; body_x[26] <= 4'd0; body_y[26] <= 4'd0;
                        body_x[27] <= 4'd0; body_y[27] <= 4'd0; body_x[28] <= 4'd0; body_y[28] <= 4'd0;
                        body_x[29] <= 4'd0; body_y[29] <= 4'd0;

                        f_x           <= 4'd12; f_y       <= 4'd4; 
                        p_x           <= 4'd2;  p_y       <= 4'd12;
                        snake_len     <= 5'd2;
                        current_state <= STATE_PLAY;
                    end else begin
                        restart_counter <= restart_counter + 1'b1;
                    end
                end
            endcase
        end
    end

    // --- FRAMEBUFFER ---
    reg [7:0] row_data_TL [0:7]; 
    reg [7:0] row_data_TR [0:7]; 
    reg [7:0] row_data_BL [0:7]; 
    reg [7:0] row_data_BR [0:7]; 
    
    reg [22:0] blink_counter;
    always @(posedge clk_50) begin
        if (!reset_n) blink_counter <= 0;
        else blink_counter <= blink_counter + 1'b1;
    end
    wire poison_visible = blink_counter[22];

    // Índices auxiliares corregidos a 3 bits para evitar WIDTHTRUNC
    wire [2:0] idx_TL = 3'd7 - h_x[2:0];
    wire [2:0] idx_TR = 3'd7 - h_x[2:0]; 

    always @(*) begin
        if (game_over) begin
            row_data_TL[0] = 8'hFF; row_data_TR[0] = 8'hFF; row_data_BL[0] = 8'hFF; row_data_BR[0] = 8'hFF;
            row_data_TL[1] = 8'hFF; row_data_TR[1] = 8'hFF; row_data_BL[1] = 8'hFF; row_data_BR[1] = 8'hFF;
            row_data_TL[2] = 8'hFF; row_data_TR[2] = 8'hFF; row_data_BL[2] = 8'hFF; row_data_BR[2] = 8'hFF;
            row_data_TL[3] = 8'hFF; row_data_TR[3] = 8'hFF; row_data_BL[3] = 8'hFF; row_data_BR[3] = 8'hFF;
            row_data_TL[4] = 8'hFF; row_data_TR[4] = 8'hFF; row_data_BL[4] = 8'hFF; row_data_BR[4] = 8'hFF;
            row_data_TL[5] = 8'hFF; row_data_TR[5] = 8'hFF; row_data_BL[5] = 8'hFF; row_data_BR[5] = 8'hFF;
            row_data_TL[6] = 8'hFF; row_data_TR[6] = 8'hFF; row_data_BL[6] = 8'hFF; row_data_BR[6] = 8'hFF;
            row_data_TL[7] = 8'hFF; row_data_TR[7] = 8'hFF; row_data_BL[7] = 8'hFF; row_data_BR[7] = 8'hFF;
        end 
        else begin
            row_data_TL[0] = 8'b0; row_data_TR[0] = 8'b0; row_data_BL[0] = 8'b0; row_data_BR[0] = 8'b0;
            row_data_TL[1] = 8'b0; row_data_TR[1] = 8'b0; row_data_BL[1] = 8'b0; row_data_BR[1] = 8'b0;
            row_data_TL[2] = 8'b0; row_data_TR[2] = 8'b0; row_data_BL[2] = 8'b0; row_data_BR[2] = 8'b0;
            row_data_TL[3] = 8'b0; row_data_TR[3] = 8'b0; row_data_BL[3] = 8'b0; row_data_BR[3] = 8'b0;
            row_data_TL[4] = 8'b0; row_data_TR[4] = 8'b0; row_data_BL[4] = 8'b0; row_data_BR[4] = 8'b0;
            row_data_TL[5] = 8'b0; row_data_TR[5] = 8'b0; row_data_BL[5] = 8'b0; row_data_BR[5] = 8'b0;
            row_data_TL[6] = 8'b0; row_data_TR[6] = 8'b0; row_data_BL[6] = 8'b0; row_data_BR[6] = 8'b0;
            row_data_TL[7] = 8'b0; row_data_TR[7] = 8'b0; row_data_BL[7] = 8'b0; row_data_BR[7] = 8'b0;

            for(r = 4'd0; r < 4'd8; r = r + 4'd1) begin
                // Cabeza (Comparaciones expandidas a 4 bits para evitar WIDTHEXPAND)
                if (h_y == r) begin 
                    if (h_x < 4'd8) row_data_TL[r[2:0]][idx_TL] = 1'b1; 
                    else            row_data_TR[r[2:0]][idx_TR] = 1'b1;
                end
                if (h_y == (r + 4'd8)) begin 
                    if (h_x < 4'd8) row_data_BL[r[2:0]][idx_TL] = 1'b1; 
                    else            row_data_BR[r[2:0]][idx_TR] = 1'b1;
                end
                
                // Cuerpo
                for(b = 5'd0; b < 5'd30; b = b + 5'd1) begin
                    if (b < (snake_len - 5'd1)) begin 
                        if (body_y[b] == r) begin
                            if (body_x[b] < 4'd8) row_data_TL[r[2:0]][3'd7 - body_x[b][2:0]] = 1'b1; 
                            else                  row_data_TR[r[2:0]][3'd7 - body_x[b][2:0]] = 1'b1;
                        end
                        if (body_y[b] == (r + 4'd8)) begin
                            if (body_x[b] < 4'd8) row_data_BL[r[2:0]][3'd7 - body_x[b][2:0]] = 1'b1; 
                            else                  row_data_BR[r[2:0]][3'd7 - body_x[b][2:0]] = 1'b1;
                        end
                    end
                end
                
                // Comida Normal
                if (f_y == r) begin
                    if (f_x < 4'd8) row_data_TL[r[2:0]][3'd7 - f_x[2:0]] = 1'b1; 
                    else            row_data_TR[r[2:0]][3'd7 - f_x[2:0]] = 1'b1;
                end
                if (f_y == (r + 4'd8)) begin
                    if (f_x < 4'd8) row_data_BL[r[2:0]][3'd7 - f_x[2:0]] = 1'b1; 
                    else            row_data_BR[r[2:0]][3'd7 - f_x[2:0]] = 1'b1;
                end

                // Veneno (Titilando)
                if (poison_active && poison_visible) begin
                    if (p_y == r) begin
                        if (p_x < 4'd8) row_data_TL[r[2:0]][3'd7 - p_x[2:0]] = 1'b1; 
                        else            row_data_TR[r[2:0]][3'd7 - p_x[2:0]] = 1'b1;
                    end
                    if (p_y == (r + 4'd8)) begin
                        if (p_x < 4'd8) row_data_BL[r[2:0]][3'd7 - p_x[2:0]] = 1'b1; 
                        else            row_data_BR[r[2:0]][3'd7 - p_x[2:0]] = 1'b1;
                    end
                end
            end
        end
    end

    // Mapeo SPI
    always @(*) begin
        case(cmd_index)
            4'd0: dynamic_command = {16'h0900, 16'h0900, 16'h0900, 16'h0900};
            4'd1: dynamic_command = {16'h0A02, 16'h0A02, 16'h0A02, 16'h0A02};
            4'd2: dynamic_command = {16'h0B07, 16'h0B07, 16'h0B07, 16'h0B07};
            4'd3: dynamic_command = {16'h0C01, 16'h0C01, 16'h0C01, 16'h0C01};
            4'h4: dynamic_command = {16'h0F00, 16'h0F00, 16'h0F00, 16'h0F00};
            
            4'd5:  dynamic_command = { {8'h01, row_data_BL[0]}, {8'h01, row_data_BR[0]}, {8'h01, row_data_TL[0]}, {8'h01, row_data_TR[0]} };
            4'd6:  dynamic_command = { {8'h02, row_data_BL[1]}, {8'h02, row_data_BR[1]}, {8'h02, row_data_TL[1]}, {8'h02, row_data_TR[1]} };
            4'd7:  dynamic_command = { {8'h03, row_data_BL[2]}, {8'h03, row_data_BR[2]}, {8'h03, row_data_TL[2]}, {8'h03, row_data_TR[2]} };
            4'd8:  dynamic_command = { {8'h04, row_data_BL[3]}, {8'h04, row_data_BR[3]}, {8'h04, row_data_TL[3]}, {8'h04, row_data_TR[3]} };
            4'd9:  dynamic_command = { {8'h05, row_data_BL[4]}, {8'h05, row_data_BR[4]}, {8'h05, row_data_TL[4]}, {8'h05, row_data_TR[4]} };
            4'd10: dynamic_command = { {8'h06, row_data_BL[5]}, {8'h06, row_data_BR[5]}, {8'h06, row_data_TL[5]}, {8'h06, row_data_TR[5]} };
            4'd11: dynamic_command = { {8'h07, row_data_BL[6]}, {8'h07, row_data_BR[6]}, {8'h07, row_data_TL[6]}, {8'h07, row_data_TR[6]} };
            4'd12: dynamic_command = { {8'h08, row_data_BL[7]}, {8'h08, row_data_BR[7]}, {8'h08, row_data_TL[7]}, {8'h08, row_data_TR[7]} };
            default: dynamic_command = 64'b0;
        endcase
    end

endmodule