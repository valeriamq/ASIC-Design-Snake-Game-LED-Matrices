module snake_top(
    input         CLOCK_50,  // Reloj de 50 MHz
    
    input  [3:0]  KEY,       // KEY3=Arriba, KEY2=Abajo, KEY1=Derecha, KEY0=Izquierda
    input  [0:0]  SW,        // SW[0] = RESET general del juego
    
    output        MAX_DIN,   // Salida de datos SPI
    output        MAX_CLK,   // Reloj SPI
    output        MAX_CS,    // Latch/Chip Select SPI
     
    output [6:0]  HEX0,      // Display 7 Segmentos: Unidades
    output [6:0]  HEX1       // Display 7 Segmentos: Decenas
);

    wire [4:0] raw_inputs = {SW[0], KEY[3:0]};
    reg  [4:0] sync_0;
    reg  [4:0] sync_1;
    reg  [4:0] clean_inputs; 
    
    reg [18:0] debounce_counter [0:4];

    integer i;
    always @(posedge CLOCK_50) begin
        if (!SW[0]) begin
            sync_0       <= 5'b11111;
            sync_1       <= 5'b11111;
            clean_inputs <= 5'b11111;
            debounce_counter[0] <= 0;
            debounce_counter[1] <= 0;
            debounce_counter[2] <= 0;
            debounce_counter[3] <= 0;
            debounce_counter[4] <= 0;
        end else begin
            sync_0 <= raw_inputs;
            sync_1 <= sync_0;
            
            for (i = 0; i < 5; i = i + 1) begin
                if (sync_1[i] == clean_inputs[i]) begin
                    debounce_counter[i] <= 0; 
                end else begin
                    debounce_counter[i] <= debounce_counter[i] + 1'b1;
                    
                    `ifdef COCOTB_SIM
                    if (debounce_counter[i] == 19'd10) begin
                    `else
                    if (debounce_counter[i] == 19'd500_000) begin
                    `endif
                        clean_inputs[i] <= sync_1[i]; 
                        debounce_counter[i] <= 0;
                    end
                end
            end
        end
    end

    wire clean_sw0  = clean_inputs[4];
    wire clean_key3 = clean_inputs[3]; 
    wire clean_key2 = clean_inputs[2]; 
    wire clean_key1 = clean_inputs[1]; 
    wire clean_key0 = clean_inputs[0]; 

    reg [15:0] div_counter;
    reg slow_clk;

    always @(posedge CLOCK_50) begin
        if (!clean_sw0) begin
            div_counter <= 0;
            slow_clk    <= 0;
        end else begin
            if(div_counter == 16'd5000) begin
                div_counter <= 0;
                slow_clk    <= ~slow_clk;
            end
            else begin
                div_counter <= div_counter + 1'b1;
            end
        end
    end

    reg [1:0] dir;
    
    always @(posedge CLOCK_50) begin
        if (!clean_sw0) begin
            dir <= 2'b00; 
        end else begin
            if (!clean_key1 && (dir != 2'b01))      dir <= 2'b00; 
            else if (!clean_key0 && (dir != 2'b00)) dir <= 2'b01; 
            else if (!clean_key3 && (dir != 2'b11)) dir <= 2'b10; 
            else if (!clean_key2 && (dir != 2'b10)) dir <= 2'b11;
        end
    end

    wire [3:0] current_cmd_index;
    wire [63:0] current_command;
    wire game_over_signal;
    wire [4:0] current_score;
     
    wire [4:0] puntos = (current_score >= 5'd2) ? (current_score - 5'd2) : 5'd0;
    
    reg [3:0] unidades;
    reg [3:0] decenas;
    
    always @(*) begin
        if (puntos >= 5'd30) begin
            decenas  = 4'd3;
            unidades = puntos[3:0] - 4'd14;
        end 
        else if (puntos >= 5'd20) begin
            decenas  = 4'd2;
            unidades = puntos[3:0] - 4'd4;
        end 
        else if (puntos >= 5'd10) begin
            decenas  = 4'd1;
            unidades = puntos[3:0] - 4'd10;
        end 
        else begin
            decenas  = 4'd0;
            unidades = puntos[3:0];
        end
    end

    wire _unused_game_over = game_over_signal;

    game_core juego (
        .clk_50(CLOCK_50),
        .reset_n(clean_sw0), 
        .dir(dir),
        .cmd_index(current_cmd_index),
        .game_over(game_over_signal),
        .snake_len(current_score),
        .dynamic_command(current_command)
    );

    spi_driver pantalla (
        .slow_clk(slow_clk),
        .reset_n(clean_sw0), 
        .dynamic_command(current_command),
        .cmd_index(current_cmd_index),
        .MAX_DIN(MAX_DIN),
        .MAX_CLK(MAX_CLK),
        .MAX_CS(MAX_CS)
    );
     
    seven_seg disp_unidades (
        .num(unidades),
        .seg(HEX0)
    );

    seven_seg disp_decenas (
        .num(decenas),
        .seg(HEX1)
    );

endmodule
