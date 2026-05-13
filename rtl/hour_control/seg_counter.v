// ============================================================
// Módulo: seg_counter
// Descripción: Genera un pulso de exactamente un ciclo de
//              reloj cada segundo.
// Parámetro:   MAX = ciclos para llegar a 1 segundo
//              Simulación: 99
//              FPGA real:  99_999_999 (1s a 100MHz)
// ============================================================
module seg_counter #(
    parameter MAX = 27'd99_999_999   // <-- cambiar a 99_999_999 para FPGA
)(
    input  wire clk,      // Reloj del sistema
    input  wire rst,      // Reset activo alto
    output reg  pulso_seg // Pulso de 1 segundo
);

reg [26:0] cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt       <= 0;
        pulso_seg <= 0;
    end else begin
        if (cnt == MAX) begin
            cnt       <= 0;
            pulso_seg <= 1;
        end else begin
            cnt       <= cnt + 1;
            pulso_seg <= 0;
        end
    end
end

endmodule