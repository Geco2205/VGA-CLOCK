`timescale 1ns / 1ps
`default_nettype none

//! @title vram
//! @author Nicole Irina Corrales Rodríguez
//! @brief Memoria de video de doble puerto usada como framebuffer del sistema VGA.
//!
//! La VRAM separa la generación de imagen de la lectura realizada por el controlador
//! VGA. Un puerto síncrono escribe los datos RGB generados y otro puerto síncrono
//! entrega el píxel solicitado para la salida de video.
module vram #(
    parameter DATA_WIDTH = 4, //! Cantidad de bits almacenados por píxel.
    parameter ADDR_WIDTH = 19, //! Ancho de las direcciones de lectura y escritura.
    parameter DEPTH      = 307200 //! Cantidad de posiciones válidas del framebuffer.
)(
    input  wire                  wr_clk, //! Reloj del puerto de escritura.
    input  wire                  rd_clk, //! Reloj del puerto de lectura.

    input  wire                  wr_en, //! Habilita la escritura de un píxel en memoria.
    input  wire [ADDR_WIDTH-1:0] wr_addr, //! Dirección de escritura del framebuffer.
    input  wire [DATA_WIDTH-1:0] wr_data, //! Dato que se almacena en la dirección de escritura.

    input  wire                  rd_en, //! Habilita la lectura síncrona desde memoria.
    input  wire [ADDR_WIDTH-1:0] rd_addr, //! Dirección de lectura solicitada por el controlador VGA.
    output reg  [DATA_WIDTH-1:0] rd_data //! Dato leído desde memoria.
);

    /*
     * Video memory.
     *
     * ram_style = "block" helps Vivado infer BRAM.
     * Do not reset the whole memory, because that can prevent BRAM inference.
     */
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1]; //! Arreglo de memoria inferido como BRAM por Vivado cuando el contexto lo permite.

    /*
     * Initial value for simulation and FPGA register initialization.
     * The memory itself is not initialized here.
     */
    //! @brief Inicializa la salida de lectura para simulación y arranque.
    initial begin
        rd_data = {DATA_WIDTH{1'b0}};
    end

    /*
     * Write port.
     * Used by image_generator.v.
     */
    //! @brief Puerto síncrono de escritura utilizado por el generador de imagen.
    always @(posedge wr_clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    /*
     * Read port.
     * Used by VGA_control.v.
     *
     * This is a synchronous read:
     * rd_data updates on the rising edge of rd_clk.
     */
    //! @brief Puerto síncrono de lectura utilizado por el controlador VGA.
    always @(posedge rd_clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end

    /*
     * Simulation-only checks.
     * These checks do not synthesize into hardware.
     * They are only here to catch wrong addresses during simulation.
     */
    //! @brief Comprobaciones de rango usadas únicamente durante simulación.
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
