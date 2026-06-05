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

    // Tu mapa original de 16x16 intacto
    reg [3:0] h_x, h_y; 
    reg [3:0] f_x, f_y; 
    reg [3:0] p_x, p_y; 
    
    // Tu largo original de serpiente (12 bloques) intacto
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

    reg [22:0] blink_counter;
    wire poison_visible = blink_counter[22];
    integer b_i;

    // LÓGICA PRINCIPAL DEL JUEGO (Sólo registra posiciones)
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
            for(b_i=1; b_i<12; b_i=b_i+1) begin
                body_x[b_i] <= 4'd0; body_y[b_i] <= 4'd0;
            end

            f_x <= 4'd12; f_y <= 4'd4; 
            p_x <= 4'd2;  p_y <= 4'd12;
            snake_len <= 5'd2;

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
                        for(b_i=11; b_i>0; b_i=b_i-1) begin
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
                        for(b_i=1; b_i<12; b_i=b_i+1) begin
                            body_x[b_i] <= 4'd0; body_y[b_i] <= 4'd0;
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
        end
    end

    // --- RENDERIZADO COMBINACIONAL AL VUELO ---
    // Esto elimina los miles de registros de pantalla y deshace el nudo de cables.
    reg [7:0] row_TL, row_TR, row_BL, row_BR;
    wire [3:0] y_top = cmd_index - 4'd5;
    wire [3:0] y_bot = cmd_index - 4'd5 + 4'd8;
    integer col, b;

    always @(*) begin
        row_TL = 8'b0; row_TR = 8'b0;
        row_BL = 8'b0; row_BR = 8'b0;

        if (game_over) begin
            row_TL = 8'hFF; row_TR = 8'hFF;
            row_BL = 8'hFF; row_BR = 8'hFF;
        end else if (cmd_index >= 4'd5 && cmd_index <= 4'd12) begin
            
            // Columnas de la izquierda (0 a 7)
            for (col = 0; col < 8; col = col + 1) begin
                // Top Left
                if (h_x == col[3:0] && h_y == y_top) row_TL[3'd7 - col[2:0]] = 1'b1;
                if (f_x == col[3:0] && f_y == y_top) row_TL[3'd7 - col[2:0]] = 1'b1;
                if (poison_active && poison_visible && p_x == col[3:0] && p_y == y_top) row_TL[3'd7 - col[2:0]] = 1'b1;
                for (b = 0; b < 12; b = b + 1) begin
                    if (b < (snake_len - 5'd1)) begin
                        if (body_x[b] == col[3:0] && body_y[b] == y_top) row_TL[3'd7 - col[2:0]] = 1'b1;
                    end
                end

                // Bottom Left
                if (h_x == col[3:0] && h_y == y_bot) row_BL[3'd7 - col[2:0]] = 1'b1;
                if (f_x == col[3:0] && f_y == y_bot) row_BL[3'd7 - col[2:0]] = 1'b1;
                if (poison_active && poison_visible && p_x == col[3:0] && p_y == y_bot) row_BL[3'd7 - col[2:0]] = 1'b1;
                for (b = 0; b < 12; b = b + 1) begin
                    if (b < (snake_len - 5'd1)) begin
                        if (body_x[b] == col[3:0] && body_y[b] == y_bot) row_BL[3'd7 - col[2:0]] = 1'b1;
                    end
                end
            end

            // Columnas de la derecha (8 a 15)
            for (col = 8; col < 16; col = col + 1) begin
                // Top Right
                if (h_x == col[3:0] && h_y == y_top) row_TR[3'd7 - col[2:0]] = 1'b1;
                if (f_x == col[3:0] && f_y == y_top) row_TR[3'd7 - col[2:0]] = 1'b1;
                if (poison_active && poison_visible && p_x == col[3:0] && p_y == y_top) row_TR[3'd7 - col[2:0]] = 1'b1;
                for (b = 0; b < 12; b = b + 1) begin
                    if (b < (snake_len - 5'd1)) begin
                        if (body_x[b] == col[3:0] && body_y[b] == y_top) row_TR[3'd7 - col[2:0]] = 1'b1;
                    end
                end

                // Bottom Right
                if (h_x == col[3:0] && h_y == y_bot) row_BR[3'd7 - col[2:0]] = 1'b1;
                if (f_x == col[3:0] && f_y == y_bot) row_BR[3'd7 - col[2:0]] = 1'b1;
                if (poison_active && poison_visible && p_x == col[3:0] && p_y == y_bot) row_BR[3'd7 - col[2:0]] = 1'b1;
                for (b = 0; b < 12; b = b + 1) begin
                    if (b < (snake_len - 5'd1)) begin
                        if (body_x[b] == col[3:0] && body_y[b] == y_bot) row_BR[3'd7 - col[2:0]] = 1'b1;
                    end
                end
            end
        end
    end

    // --- MAPEO SPI COMBINACIONAL ---
    always @(*) begin
        case(cmd_index)
            4'd0: dynamic_command = {16'h0900, 16'h0900, 16'h0900, 16'h0900};
            4'd1: dynamic_command = {16'h0A02, 16'h0A02, 16'h0A02, 16'h0A02};
            4'd2: dynamic_command = {16'h0B07, 16'h0B07, 16'h0B07, 16'h0B07};
            4'd3: dynamic_command = {16'h0C01, 16'h0C01, 16'h0C01, 16'h0C01};
            4'h4: dynamic_command = {16'h0F00, 16'h0F00, 16'h0F00, 16'h0F00};
            
            4'd5:  dynamic_command = { {8'h01, row_BL}, {8'h01, row_BR}, {8'h01, row_TL}, {8'h01, row_TR} };
            4'd6:  dynamic_command = { {8'h02, row_BL}, {8'h02, row_BR}, {8'h02, row_TL}, {8'h02, row_TR} };
            4'd7:  dynamic_command = { {8'h03, row_BL}, {8'h03, row_BR}, {8'h03, row_TL}, {8'h03, row_TR} };
            4'd8:  dynamic_command = { {8'h04, row_BL}, {8'h04, row_BR}, {8'h04, row_TL}, {8'h04, row_TR} };
            4'd9:  dynamic_command = { {8'h05, row_BL}, {8'h05, row_BR}, {8'h05, row_TL}, {8'h05, row_TR} };
            4'd10: dynamic_command = { {8'h06, row_BL}, {8'h06, row_BR}, {8'h06, row_TL}, {8'h06, row_TR} };
            4'd11: dynamic_command = { {8'h07, row_BL}, {8'h07, row_BR}, {8'h07, row_TL}, {8'h07, row_TR} };
            4'd12: dynamic_command = { {8'h08, row_BL}, {8'h08, row_BR}, {8'h08, row_TL}, {8'h08, row_TR} };
            default: dynamic_command = 64'b0;
        endcase
    end

endmodule