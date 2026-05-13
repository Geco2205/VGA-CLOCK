`timescale 1ns / 1ps

//! @title  sincronizador - Sincronizador de doble flip-flop
//! @author Keillin Loaisiga
//!
//! Sincroniza una señal externa al dominio del reloj del sistema
//! mediante una cadena de dos flip-flops en serie.
//! Este esquema evita la metaestabilidad que puede ocurrir cuando
//! una señal asíncrona es muestreada directamente por lógica síncrona.
//!
//! El primer flip-flop captura la señal externa y puede quedar en
//! estado metaestable; el segundo flip-flop le da tiempo suficiente
//! para resolver ese estado antes de que la señal sea usada.

module sincronizador (
    input  wire clk,  //! Reloj del sistema: 100 MHz (Nexys A7)
    input  wire rst,  //! Reset síncrono activo alto
    input  wire din,  //! Señal externa asíncrona a sincronizar
    output wire dout  //! Señal sincronizada al dominio del reloj
);

    reg ff1; //! Primer flip-flop: captura la señal externa
    reg ff2; //! Segundo flip-flop: estabiliza y elimina metaestabilidad

    always @(posedge clk or posedge rst) begin: sync_chain
        if (rst) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin
            ff1 <= din;  //! Captura la señal asíncrona
            ff2 <= ff1;  //! Estabiliza antes de entregar al sistema
        end
    end

    assign dout = ff2; //! Salida sincronizada

endmodule