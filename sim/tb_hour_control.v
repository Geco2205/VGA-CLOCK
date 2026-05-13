`timescale 1ns/1ps

module tb_hour_control;

// --- Señales ---
reg        clk, rst;
reg  [8:0] sw;
reg        btn_c, btn_r;
wire [3:0] hora_dec, hora_uni;
wire [3:0] min_dec,  min_uni;
wire [3:0] seg_dec,  seg_uni;
wire [1:0] estado;

// --- Instancia del módulo ---
hour_control uut (
    .clk(clk), .rst(rst), .sw(sw),
    .btn_c(btn_c), .btn_r(btn_r),
    .hora_dec(hora_dec), .hora_uni(hora_uni),
    .min_dec(min_dec),   .min_uni(min_uni),
    .seg_dec(seg_dec),   .seg_uni(seg_uni),
    .estado(estado)
);

// --- Reloj 100MHz (periodo 10ns) ---
initial clk = 0;
always #5 clk = ~clk;

// --- Secuencia de prueba ---
initial begin
    // Inicializar
    rst = 1; sw = 0; btn_c = 0; btn_r = 0;
    #100;
    rst = 0;
    #100;

    $display("=== PRUEBA 1: Estado inicial ===");
    $display("Estado: %0d | Hora: %0d%0d:%0d%0d:%0d%0d",
              estado, hora_dec, hora_uni,
              min_dec, min_uni, seg_dec, seg_uni);

    // --- Ir a SET_HOURS con BTNC ---
    $display("=== PRUEBA 2: Avanzar a SET_HOURS con BTNC ===");
    btn_r = 1; #500; btn_r = 0; #500;
    $display("Estado: %0d (esperado 1=SET_MIN)", estado);

    btn_r = 1; #500; btn_r = 0; #500;
    $display("Estado: %0d (esperado 0=SET_HOURS)", estado);

    // --- Ajustar hora a 12 ---
    $display("=== PRUEBA 3: Ajustar hora a 12 ===");
    sw[8] = 1;
    sw[7:4] = 4'd1;
    sw[3:0] = 4'd2;
    #500;
    $display("Hora: %0d%0d (esperado 12)", hora_dec, hora_uni);

    // --- Ir a SET_MIN ---
    btn_c = 1; #500; btn_c = 0; #500;
    $display("Estado: %0d (esperado 1=SET_MIN)", estado);

    // --- Ajustar minutos a 30 ---
    $display("=== PRUEBA 4: Ajustar minutos a 30 ===");
    sw[7:4] = 4'd3;
    sw[3:0] = 4'd0;
    #500;
    $display("Minutos: %0d%0d (esperado 30)", min_dec, min_uni);

    // --- Ir a RUN ---
    btn_c = 1; #500; btn_c = 0; #500;
    sw[8] = 0;
    $display("Estado: %0d (esperado 2=RUN)", estado);

    // --- Esperar varios segundos simulados ---
    $display("=== PRUEBA 5: Verificar conteo de segundos ===");
    #50000; // esperar varios pulsos de segundo
    $display("Hora: %0d%0d:%0d%0d:%0d%0d",
              hora_dec, hora_uni,
              min_dec, min_uni,
              seg_dec, seg_uni);

    // --- Verificar retroceso ---
    $display("=== PRUEBA 6: Retroceder con BTNR ===");
    btn_r = 1; #500; btn_r = 0; #500;
    $display("Estado tras BTNR: %0d (esperado 1=SET_MIN)", estado);

    btn_r = 1; #500; btn_r = 0; #500;
    $display("Estado tras BTNR: %0d (esperado 0=SET_HOURS)", estado);

    $display("=== Simulacion completa ===");
    $finish;
end

// Monitor continuo
initial begin
    $monitor("t=%0t | estado=%0d | %0d%0d:%0d%0d:%0d%0d",
              $time, estado,
              hora_dec, hora_uni,
              min_dec, min_uni,
              seg_dec, seg_uni);
end

endmodule