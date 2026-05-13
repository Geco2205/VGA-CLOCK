// ============================================================
// Módulo: debounce
// Descripción: Elimina el ruido mecánico de botones físicos.
//              Genera un pulso limpio de un solo ciclo al
//              detectar un flanco de subida estable.
// Parámetro:   CYCLES = ciclos de espera para estabilización
//              Simulación: 9
//              FPGA real:  1_999_999 (20ms a 100MHz)
// ============================================================
module debounce #(
    parameter CYCLES = 21'd1_999_999   // <-- cambiar a 1_999_999 para FPGA
)(
    input  wire clk,    // Reloj del sistema
    input  wire rst,    // Reset activo alto
    input  wire din,    // Señal con ruido (ya sincronizada)
    output reg  pulso   // Pulso limpio de un solo ciclo
);

reg [20:0] contador;
reg        estado_actual;
reg        din_prev;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        contador      <= 0;
        estado_actual <= 0;
        din_prev      <= 0;
        pulso         <= 0;
    end else begin
        pulso    <= 0;        // por defecto el pulso es 0
        din_prev <= din;

        if (din != estado_actual) begin
            // señal cambió, empezar a contar
            if (contador == CYCLES) begin
                estado_actual <= din;
                contador      <= 0;
                // solo generar pulso en flanco de subida
                if (din == 1'b1)
                    pulso <= 1;
            end else begin
                contador <= contador + 1;
            end
        end else begin
            // señal estable, reiniciar contador
            contador <= 0;
        end
    end
end

endmodule