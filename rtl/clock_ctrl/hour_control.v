// ============================================================
// Módulo: hour_control
// Descripción: Controla la hora actual, maneja ajuste mediante
//              switches y botones con debounce y sincronización
// ============================================================
module hour_control (
    input  wire       clk,      // Reloj 100 MHz
    input  wire       rst,      // Reset activo alto
    input  wire [8:0] sw,       // SW[7:0]=ajuste, SW[8]=modo ajuste
    input  wire       btn_c,    // Avanzar estado
    input  wire       btn_r,    // Retroceder estado
    output reg  [3:0] hora_dec, // Decenas de hora (0-2)
    output reg  [3:0] hora_uni, // Unidades de hora (0-9)
    output reg  [3:0] min_dec,  // Decenas de minuto (0-5)
    output reg  [3:0] min_uni,  // Unidades de minuto (0-9)
    output reg  [3:0] seg_dec,  // Decenas de segundo
    output reg  [3:0] seg_uni,  // Unidades de segundo
    output reg  [1:0] estado    // 0=SET_HOURS,1=SET_MIN,2=RUN
);

// ============================================================
// Parámetros de estado
// ============================================================
localparam SET_HOURS = 2'd0;
localparam SET_MIN   = 2'd1;
localparam RUN       = 2'd2;

// ============================================================
// Contador para generar pulso de 1 segundo
// NOTA: En simulación usamos 100 ciclos para ver resultados
//       rápido. Para síntesis en FPGA cambiar a 99_999_999
// ============================================================
reg [26:0] cnt_seg;
reg        pulso_seg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt_seg   <= 0;
        pulso_seg <= 0;
    end else begin
        if (cnt_seg == 27'd99) begin  // <-- cambiar a 99_999_999 para FPGA
            cnt_seg   <= 0;
            pulso_seg <= 1;
        end else begin
            cnt_seg   <= cnt_seg + 1;
            pulso_seg <= 0;
        end
    end
end

// ============================================================
// Doble FF sincronizador + detección de flanco para botones
// ============================================================
reg btn_c_s0, btn_c_s1, btn_c_s2;
reg btn_r_s0, btn_r_s1, btn_r_s2;
wire btn_c_pulso = btn_c_s1 & ~btn_c_s2;
wire btn_r_pulso = btn_r_s1 & ~btn_r_s2;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        btn_c_s0 <= 0; btn_c_s1 <= 0; btn_c_s2 <= 0;
        btn_r_s0 <= 0; btn_r_s1 <= 0; btn_r_s2 <= 0;
    end else begin
        btn_c_s0 <= btn_c; btn_c_s1 <= btn_c_s0; btn_c_s2 <= btn_c_s1;
        btn_r_s0 <= btn_r; btn_r_s1 <= btn_r_s0; btn_r_s2 <= btn_r_s1;
    end
end

// ============================================================
// Debounce para botones
// NOTA: En simulación usamos 9 ciclos para ver resultados
//       rápido. Para síntesis en FPGA cambiar a 1_999_999
// ============================================================
reg [20:0] db_cnt_c, db_cnt_r;
reg        btn_c_db, btn_r_db;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        db_cnt_c <= 0; btn_c_db <= 0;
    end else begin
        if (btn_c_s1 != btn_c_db) begin
            if (db_cnt_c == 21'd9) begin  // <-- cambiar a 1_999_999 para FPGA
                btn_c_db <= btn_c_s1;
                db_cnt_c <= 0;
            end else
                db_cnt_c <= db_cnt_c + 1;
        end else
            db_cnt_c <= 0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        db_cnt_r <= 0; btn_r_db <= 0;
    end else begin
        if (btn_r_s1 != btn_r_db) begin
            if (db_cnt_r == 21'd9) begin  // <-- cambiar a 1_999_999 para FPGA
                btn_r_db <= btn_r_s1;
                db_cnt_r <= 0;
            end else
                db_cnt_r <= db_cnt_r + 1;
        end else
            db_cnt_r <= 0;
    end
end

// ============================================================
// Máquina de estados + lógica de hora
// ============================================================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        estado   <= RUN;
        hora_dec <= 0; hora_uni <= 0;
        min_dec  <= 0; min_uni  <= 0;
        seg_dec  <= 0; seg_uni  <= 0;
    end else begin

        // --- Cambio de estado con botones ---
        if (btn_c_pulso) begin
            if (estado == SET_HOURS) estado <= SET_MIN;
            else if (estado == SET_MIN) estado <= RUN;
        end
        if (btn_r_pulso) begin
            if (estado == RUN)          estado <= SET_MIN;
            else if (estado == SET_MIN) estado <= SET_HOURS;
        end

        // --- Ajuste de hora con switches cuando SW[8]=1 ---
        if (sw[8] && estado == SET_HOURS) begin
            hora_dec <= sw[7:4] > 4'd2 ? 4'd2 : sw[7:4];
            hora_uni <= sw[3:0] > 4'd9 ? 4'd9 : sw[3:0];
        end
        if (sw[8] && estado == SET_MIN) begin
            min_dec <= sw[7:4] > 4'd5 ? 4'd5 : sw[7:4];
            min_uni <= sw[3:0] > 4'd9 ? 4'd9 : sw[3:0];
        end

        // --- Conteo automático en modo RUN ---
        if (estado == RUN && pulso_seg) begin
            // Segundos
            if (seg_uni == 4'd9) begin
                seg_uni <= 0;
                if (seg_dec == 4'd5) begin
                    seg_dec <= 0;
                    // Minutos
                    if (min_uni == 4'd9) begin
                        min_uni <= 0;
                        if (min_dec == 4'd5) begin
                            min_dec <= 0;
                            // Horas
                            if (hora_dec == 4'd2 && hora_uni == 4'd3) begin
                                hora_dec <= 0; hora_uni <= 0;
                            end else if (hora_uni == 4'd9) begin
                                hora_uni <= 0;
                                hora_dec <= hora_dec + 1;
                            end else
                                hora_uni <= hora_uni + 1;
                        end else
                            min_dec <= min_dec + 1;
                    end else
                        min_uni <= min_uni + 1;
                end else
                    seg_dec <= seg_dec + 1;
            end else
                seg_uni <= seg_uni + 1;
        end

    end
end

endmodule