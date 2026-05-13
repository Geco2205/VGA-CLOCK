// ============================================================
// Módulo: hour_control
// Descripción: Controla la hora actual. Instancia módulos de
//              sincronización, debounce y contador de segundos.
//              Maneja máquina de estados y lógica de hora.
// ============================================================
module hour_control (
    input  wire       clk,
    input  wire       rst,
    input  wire [8:0] sw,
    input  wire       btn_c,
    input  wire       btn_r,
    output reg  [3:0] hora_dec,
    output reg  [3:0] hora_uni,
    output reg  [3:0] min_dec,
    output reg  [3:0] min_uni,
    output reg  [3:0] seg_dec,
    output reg  [3:0] seg_uni,
    output reg  [1:0] estado
);

localparam SET_HOURS = 2'd0;
localparam SET_MIN   = 2'd1;
localparam RUN       = 2'd2;

// ============================================================
// Señales internas
// ============================================================
wire btn_c_sync, btn_r_sync;  // botones sincronizados
wire btn_c_pulso, btn_r_pulso; // pulsos limpios sin rebote
wire pulso_seg;                // pulso de 1 segundo

// ============================================================
// Instancias de sincronizadores (uno por botón)
// ============================================================
sincronizador sync_btnc (
    .clk  (clk),
    .rst  (rst),
    .din  (btn_c),
    .dout (btn_c_sync)
);

sincronizador sync_btnr (
    .clk  (clk),
    .rst  (rst),
    .din  (btn_r),
    .dout (btn_r_sync)
);

// ============================================================
// Instancias de debounce (uno por botón)
// ============================================================
debounce db_btnc (
    .clk   (clk),
    .rst   (rst),
    .din   (btn_c_sync),
    .pulso (btn_c_pulso)
);

debounce db_btnr (
    .clk   (clk),
    .rst   (rst),
    .din   (btn_r_sync),
    .pulso (btn_r_pulso)
);

// ============================================================
// Instancia del contador de segundos
// ============================================================
seg_counter sc (
    .clk      (clk),
    .rst      (rst),
    .pulso_seg(pulso_seg)
);

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

        // --- Ajuste con switches cuando SW[8]=1 ---
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
            if (seg_uni == 4'd9) begin
                seg_uni <= 0;
                if (seg_dec == 4'd5) begin
                    seg_dec <= 0;
                    if (min_uni == 4'd9) begin
                        min_uni <= 0;
                        if (min_dec == 4'd5) begin
                            min_dec <= 0;
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