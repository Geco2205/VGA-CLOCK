`timescale 1ns / 1ps

//! @title  debounce - Eliminador de rebote mecánico
//! @author Keillin Loaisiga
//!
//! Elimina el ruido mecánico (bouncing) producido por botones físicos.
//! Detecta un flanco de subida estable al verificar que la señal de
//! entrada permanece en su nuevo nivel durante al menos CYCLES ciclos
//! consecutivos antes de considerarla válida.
//! Cuando se confirma un flanco de subida, genera un pulso limpio
//! de exactamente un ciclo de reloj.
//!
//! Para simulación usar CYCLES = 9.
//! Para FPGA Nexys A7 a 100 MHz usar CYCLES = 1_999_999 (20 ms).

module debounce #(
    parameter CYCLES = 21'd1_999_999 //! Ciclos de espera para estabilización (20 ms a 100 MHz)
)(
    input  wire clk,   //! Reloj del sistema: 100 MHz (Nexys A7)
    input  wire rst,   //! Reset síncrono activo alto
    input  wire din,   //! Señal con ruido proveniente del botón (ya sincronizada)
    output reg  pulso  //! Pulso limpio de un solo ciclo en flanco de subida confirmado
);

    reg [20:0] contador;      //! Contador de ciclos de estabilización
    reg        estado_actual; //! Último nivel estable confirmado de la señal
    reg        din_prev;      //! Valor previo de din (no utilizado en lógica actual, reservado)

    always @(posedge clk or posedge rst) begin: debounce_fsm
        if (rst) begin
            contador      <= 21'd0;
            estado_actual <= 1'b0;
            din_prev      <= 1'b0;
            pulso         <= 1'b0;
        end else begin
            pulso    <= 1'b0; //! El pulso es 0 por defecto en cada ciclo
            din_prev <= din;

            if (din != estado_actual) begin
                //! La señal cambió: contar ciclos de estabilización
                if (contador == CYCLES) begin
                    estado_actual <= din;
                    contador      <= 21'd0;
                    if (din == 1'b1)
                        pulso <= 1'b1; //! Flanco de subida confirmado: generar pulso
                end else begin
                    contador <= contador + 21'd1;
                end
            end else begin
                contador <= 21'd0; //! Señal estable: reiniciar contador
            end
        end
    end

endmodule