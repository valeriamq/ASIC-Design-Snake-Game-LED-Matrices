module spi_driver(
    input slow_clk,
    input reset_n, // <-- NUEVA ENTRADA DE RESET
    input [63:0] dynamic_command,
    output reg [3:0] cmd_index = 0,
    output MAX_DIN,
    output MAX_CLK,
    output MAX_CS
);

    reg din_reg = 0;
    reg clk_reg = 0;
    reg cs_reg  = 1;

    assign MAX_DIN = din_reg;
    assign MAX_CLK = clk_reg;
    assign MAX_CS  = cs_reg;

    reg [63:0] shift_reg = 0;
    reg [6:0] bit_count = 0;
    reg [2:0] state = 0;

    always @(posedge slow_clk) begin
        if (!reset_n) begin
            // Estado inicial seguro y limpio en caso de reset
            state     <= 0;
            cmd_index <= 0;
            cs_reg    <= 1;
            clk_reg   <= 0;
            din_reg   <= 0;
            shift_reg <= 0;
            bit_count <= 0;
        end else begin
            case(state)
                0: begin
                    shift_reg <= dynamic_command; 
                    bit_count <= 64;
                    cs_reg    <= 0;
                    clk_reg   <= 0;
                    state     <= 1;
                end
                1: begin
                    din_reg <= shift_reg[63];
                    state   <= 2;
                end
                2: begin
                    state <= 3;
                end
                3: begin
                    clk_reg <= 1;
                    state   <= 4;
                end
                4: begin
                    clk_reg   <= 0;
                    shift_reg <= shift_reg << 1;
                    bit_count <= bit_count - 1;
                    if(bit_count == 1) state <= 5;
                    else               state <= 1;
                end
                5: begin
                    cs_reg <= 1;
                    if(cmd_index < 12) begin
                        cmd_index <= cmd_index + 1;
                        state     <= 0;
                    end
                    else begin
                        cmd_index <= 4'd5; 
                        state     <= 0;
                    end
                end
                default: state <= 0;
            endcase
        end
    end

endmodule