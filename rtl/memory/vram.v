`timescale 1ns / 1ps
`default_nettype none

/**
 * Módulo: vram
 *
 * Memoria de video de doble puerto para el framebuffer VGA.
 * El puerto de escritura recibe los píxeles generados por
 * image_generator y el puerto de lectura entrega datos al
 * controlador VGA.
 *
 * Parámetros:
 *   DATA_WIDTH : cantidad de bits por píxel.
 *                4  = índice de color / modo con paleta.
 *                12 = color directo RGB444.
 *   ADDR_WIDTH : ancho de dirección.
 *   DEPTH      : cantidad de posiciones válidas de memoria.
 */
module vram #(
    parameter DATA_WIDTH = 4,
    parameter ADDR_WIDTH = 19,
    parameter DEPTH      = 307200
)(
    input  wire                  wr_clk,
    input  wire                  rd_clk,

    input  wire                  wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [DATA_WIDTH-1:0] wr_data,

    input  wire                  rd_en,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [DATA_WIDTH-1:0] rd_data
);

    /*
     * Arreglo principal de memoria.
     *
     * El atributo ram_style orienta a Vivado para inferir BRAM.
     * No se reinicia todo el arreglo, ya que eso puede impedir
     * una inferencia correcta de memoria de bloque.
     */
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    /*
     * Valor inicial del registro de salida.
     * La memoria completa no se inicializa en este bloque.
     */
    initial begin
        rd_data = {DATA_WIDTH{1'b0}};
    end

    /*
     * Puerto de escritura.
     * Recibe dirección, dato y habilitación desde image_generator.
     */
    always @(posedge wr_clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    /*
     * Puerto de lectura.
     * La lectura es síncrona: rd_data se actualiza en el flanco
     * positivo de rd_clk cuando rd_en está activo.
     */
    always @(posedge rd_clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end

    /*
     * Verificaciones para simulación.
     * No se sintetizan en hardware; sirven para detectar accesos
     * fuera de rango durante pruebas.
     */
    // synthesis translate_off
    always @(posedge wr_clk) begin
        if (wr_en && (wr_addr >= DEPTH)) begin
            $display("[VRAM ERROR] Write address out of range: wr_addr=%0d, DEPTH=%0d, time=%0t",
                     wr_addr, DEPTH, $time);
            $stop;
        end
    end

    always @(posedge rd_clk) begin
        if (rd_en && (rd_addr >= DEPTH)) begin
            $display("[VRAM ERROR] Read address out of range: rd_addr=%0d, DEPTH=%0d, time=%0t",
                     rd_addr, DEPTH, $time);
            $stop;
        end
    end
    // synthesis translate_on

endmodule

`default_nettype wire