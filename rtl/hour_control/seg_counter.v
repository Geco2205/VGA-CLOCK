`timescale 1ns / 1ps

//! @title  seg_counter - Contador de segundos
//! @author Keillin Loaisiga
//!
//! Genera un pulso de exactamente un ciclo de reloj cada segundo.
//! Cuenta ciclos de reloj hasta alcanzar el valor MAX y en ese
//! momento activa pulso_seg por un único ciclo antes de reiniciar.
//!
//! Para simulación usar MAX = 99.
//! Para FPGA Nexys A7 a 100 MHz usar MAX = 99_999_999 (1 segundo).

module seg_counter #(
    parameter MAX = 27'd99_999_999 //! Ciclos de reloj para completar 1 segundo (100 MHz)
)(
    input  wire clk,       //! Reloj del sistema: 100 MHz (Nexys A7)
    input  wire rst,       //! Reset síncrono activo alto
    output reg  pulso_seg  //! Pulso de un ciclo activo cada segundo
);

    reg [26:0] cnt; //! Contador interno de ciclos de reloj

    always @(posedge clk or posedge rst) begin: second_counter
        if (rst) begin
            cnt       <= 27'd0;
            pulso_seg <= 1'b0;
        end else begin
            if (cnt == MAX) begin
                cnt       <= 27'd0;
                pulso_seg <= 1'b1; //! Pulso activo al completar 1 segundo
            end else begin
                cnt       <= cnt + 27'd1;
                pulso_seg <= 1'b0;
            end
        end
    end

endmodule