// ============================================================
// Módulo: sincronizador
// Descripción: Sincroniza una señal externa al dominio del
//              reloj usando doble flip-flop. Evita 
//              metaestabilidad en señales asíncronas.
// ============================================================
module sincronizador (
    input  wire clk,    // Reloj del sistema
    input  wire rst,    // Reset activo alto
    input  wire din,    // Señal externa a sincronizar
    output wire dout    // Señal sincronizada
);

reg ff1, ff2;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ff1 <= 0;
        ff2 <= 0;
    end else begin
        ff1 <= din;   // primer flip-flop: captura
        ff2 <= ff1;   // segundo flip-flop: estabiliza
    end
end

assign dout = ff2;

endmodule