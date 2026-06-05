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

    // =======================================================
    // --- FILTRO ANTIRREBOTE (DEBOUNCER) MULTICANAL ---
    // =======================================================
    // Concatenamos las 5 entradas físicas: {SW0, KEY3, KEY2, KEY1, KEY0}
    wire [4:0] raw_inputs = {SW[0], KEY[3:0]};
    reg  [4:0] sync_0 = 5'b11111;
    reg  [4:0] sync_1 = 5'b11111;
    reg  [4:0] clean_inputs = 5'b11111; // Aquí se guardan los botones limpios
    
    // Contadores individuales para cada botón (19 bits alcanzan para 500,000)
    reg [18:0] debounce_counter [0:4];

integer i;
    always @(posedge CLOCK_50) begin
        // 1. Sincronización para evitar metaestabilidad
        sync_0 <= raw_inputs;
        sync_1 <= sync_0;
        
        // 2. Lógica de filtro para los 5 canales
        for (i = 0; i < 5; i = i + 1) begin
            if (sync_1[i] == clean_inputs[i]) begin
                debounce_counter[i] <= 0; // Si no hay cambio, el contador se reinicia
            end else begin
                debounce_counter[i] <= debounce_counter[i] + 1'b1;
                
                // --- CAMBIO AQUÍ: Filtro inteligente para Simulación vs Chip Real ---
                `ifdef COCOTB_SIM
                if (debounce_counter[i] == 19'd10) begin
                `else
                if (debounce_counter[i] == 19'd500_000) begin
                `endif
                    clean_inputs[i] <= sync_1[i]; // Aceptamos el nuevo estado
                    debounce_counter[i] <= 0;
                end
            end
        end
    end

    // Extraemos las señales limpias para usarlas en el resto del código
    wire clean_sw0  = clean_inputs[4];
    wire clean_key3 = clean_inputs[3]; // Arriba
    wire clean_key2 = clean_inputs[2]; // Abajo
    wire clean_key1 = clean_inputs[1]; // Derecha
    wire clean_key0 = clean_inputs[0]; // Izquierda

    // =======================================================
    // --- DIVISOR DE RELOJ PARA EL SPI ---
    // =======================================================
    reg [15:0] div_counter = 0;
    reg slow_clk = 0;

    always @(posedge CLOCK_50) begin
        if(div_counter == 16'd5000) begin
            div_counter <= 0;
            slow_clk <= ~slow_clk;
        end
        else begin
            div_counter <= div_counter + 1'b1;
        end
    end

    // =======================================================
    // --- REGISTRO Y CONTROL DE DIRECCIÓN SEGURO ---
    // =======================================================
    reg [1:0] dir;
    
    // Usamos lógica síncrona usando el reloj y el SW0 limpio
    always @(posedge CLOCK_50) begin
        if (!clean_sw0) begin
            dir <= 2'b00; // Al resetear, la serpiente apunta a la derecha
        end else begin
            // Derecha (No permite cambiar si vas a la Izquierda)
            if (!clean_key1 && (dir != 2'b01))      dir <= 2'b00; 
            // Izquierda (No permite cambiar si vas a la Derecha)
            else if (!clean_key0 && (dir != 2'b00)) dir <= 2'b01; 
            // Arriba (No permite cambiar si vas Abajo)
            else if (!clean_key3 && (dir != 2'b11)) dir <= 2'b10; 
            // Abajo (No permite cambiar si vas Arriba)
            else if (!clean_key2 && (dir != 2'b10)) dir <= 2'b11;
        end
    end

    // =======================================================
    // --- INTERCONEXIÓN Y PUNTAJES ---
    // =======================================================
    wire [3:0] current_cmd_index;
    wire [63:0] current_command;
    wire game_over_signal;
    wire [4:0] current_score;
     
    // Restamos 2 de la longitud inicial de la serpiente
    wire [4:0] puntos = (current_score >= 5'd2) ? (current_score - 5'd2) : 5'd0;
    
    // Separador combinacional de decenas y unidades
    reg [3:0] unidades;
    reg [3:0] decenas;
    
    // ¡MODIFICADO! Lógica BCD corregida y expandida
    always @(*) begin
        if (puntos >= 5'd30) begin
            decenas  = 4'd3;
            unidades = puntos - 5'd30;
        end 
        else if (puntos >= 5'd20) begin
            decenas  = 4'd2;
            unidades = puntos - 5'd20;
        end 
        else if (puntos >= 5'd10) begin
            decenas  = 4'd1;
            unidades = puntos - 5'd10;
        end 
        else begin
            decenas  = 4'd0;
            unidades = puntos[3:0];
        end
    end

    // =======================================================
    // --- INSTANCIACIÓN DE MÓDULOS ---
    // =======================================================
    game_core juego (
        .clk_50(CLOCK_50),
        .reset_n(clean_sw0), // Conectado al Switch 0 limpio
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