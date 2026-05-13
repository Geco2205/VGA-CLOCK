`timescale 1ns / 1ps

//! @title  hour_control - Controlador de hora con máquina de estados
//! @author Keillin Loaisiga
//!
//! Controla la hora actual del reloj digital. Instancia internamente
//! los módulos sincronizador, debounce y seg_counter para manejar
//! correctamente las entradas físicas y el conteo de tiempo.
//!
//! La máquina de estados tiene tres modos de operación:
//!   - SET_HOURS (2'd0): ajuste de horas mediante switches
//!   - SET_MIN   (2'd1): ajuste de minutos mediante switches
//!   - RUN       (2'd2): conteo automático de tiempo
//!
//! Navegación de estados:
//!   - BTNC avanza: SET_HOURS → SET_MIN → RUN
//!   - BTNR retrocede: RUN → SET_MIN → SET_HOURS
//!
//! Ajuste de hora con SW[8]=1:
//!   - SW[7:4] controla las decenas, SW[3:0] controla las unidades
//!   - Horas válidas: 00-23. Cuando decena=2, unidad se limita a 0-3
//!   - Minutos válidos: 00-59

module hour_control (
    input  wire       clk,        //! Reloj del sistema: 100 MHz (Nexys A7)
    input  wire       rst,        //! Reset síncrono activo alto
    input  wire [8:0] sw,         //! Switches: SW[8]=habilita ajuste, SW[7:4]=decenas, SW[3:0]=unidades
    input  wire       btn_c,      //! Botón central: avanza estado
    input  wire       btn_r,      //! Botón derecho: retrocede estado
    output reg  [3:0] hora_dec,   //! Dígito de decenas de la hora (0-2)
    output reg  [3:0] hora_uni,   //! Dígito de unidades de la hora (0-9, máx 3 si decena=2)
    output reg  [3:0] min_dec,    //! Dígito de decenas de los minutos (0-5)
    output reg  [3:0] min_uni,    //! Dígito de unidades de los minutos (0-9)
    output reg  [3:0] seg_dec,    //! Dígito de decenas de los segundos (0-5)
    output reg  [3:0] seg_uni,    //! Dígito de unidades de los segundos (0-9)
    output reg  [1:0] estado      //! Estado actual de la máquina: 0=SET_HOURS, 1=SET_MIN, 2=RUN
);

    localparam SET_HOURS = 2'd0; //! Estado de ajuste de horas
    localparam SET_MIN   = 2'd1; //! Estado de ajuste de minutos
    localparam RUN       = 2'd2; //! Estado de conteo automático

    // -------------------------------------------------------------------------
    // Señales internas
    // -------------------------------------------------------------------------

    wire btn_c_sync;  //! btn_c sincronizado al dominio del reloj
    wire btn_r_sync;  //! btn_r sincronizado al dominio del reloj
    wire btn_c_pulso; //! Pulso limpio de un ciclo para btn_c
    wire btn_r_pulso; //! Pulso limpio de un ciclo para btn_r
    wire pulso_seg;   //! Pulso de un ciclo activo cada segundo

    // -------------------------------------------------------------------------
    // Instancias de sincronizadores
    // -------------------------------------------------------------------------

    sincronizador sync_btnc ( //! Sincroniza btn_c al dominio del reloj
        .clk  (clk),
        .rst  (rst),
        .din  (btn_c),
        .dout (btn_c_sync)
    );

    sincronizador sync_btnr ( //! Sincroniza btn_r al dominio del reloj
        .clk  (clk),
        .rst  (rst),
        .din  (btn_r),
        .dout (btn_r_sync)
    );

    // -------------------------------------------------------------------------
    // Instancias de debounce
    // -------------------------------------------------------------------------

    debounce db_btnc ( //! Elimina rebote de btn_c
        .clk   (clk),
        .rst   (rst),
        .din   (btn_c_sync),
        .pulso (btn_c_pulso)
    );

    debounce db_btnr ( //! Elimina rebote de btn_r
        .clk   (clk),
        .rst   (rst),
        .din   (btn_r_sync),
        .pulso (btn_r_pulso)
    );

    // -------------------------------------------------------------------------
    // Instancia del contador de segundos
    // -------------------------------------------------------------------------

    seg_counter sc ( //! Genera pulso de 1 segundo para el conteo automático
        .clk      (clk),
        .rst      (rst),
        .pulso_seg(pulso_seg)
    );

    // -------------------------------------------------------------------------
    // Máquina de estados + lógica de hora
    // -------------------------------------------------------------------------

    always @(posedge clk or posedge rst) begin: hour_fsm
        if (rst) begin
            estado   <= RUN;
            hora_dec <= 4'd0; hora_uni <= 4'd0;
            min_dec  <= 4'd0; min_uni  <= 4'd0;
            seg_dec  <= 4'd0; seg_uni  <= 4'd0;
        end else begin

            //! Navegación de estados con BTNC (avanza) y BTNR (retrocede)
            if (btn_c_pulso) begin
                if      (estado == SET_HOURS) estado <= SET_MIN;
                else if (estado == SET_MIN)   estado <= RUN;
            end
            if (btn_r_pulso) begin
                if      (estado == RUN)     estado <= SET_MIN;
                else if (estado == SET_MIN) estado <= SET_HOURS;
            end

            //! Ajuste de horas con SW[8]=1 en estado SET_HOURS
            if (sw[8] && estado == SET_HOURS) begin
                hora_dec <= sw[7:4] > 4'd2 ? 4'd2 : sw[7:4];
                //! Limita unidades: máx 3 si decena=2, máx 9 si decena<2
                hora_uni <= (sw[7:4] >= 4'd2 && sw[3:0] > 4'd3) ? 4'd3 :
                            (sw[7:4] <  4'd2 && sw[3:0] > 4'd9) ? 4'd9 :
                            sw[3:0];
            end

            //! Ajuste de minutos con SW[8]=1 en estado SET_MIN
            if (sw[8] && estado == SET_MIN) begin
                min_dec <= sw[7:4] > 4'd5 ? 4'd5 : sw[7:4];
                min_uni <= sw[3:0] > 4'd9 ? 4'd9 : sw[3:0];
            end

            //! Conteo automático en modo RUN: incrementa cada segundo
            if (estado == RUN && pulso_seg) begin
                if (seg_uni == 4'd9) begin
                    seg_uni <= 4'd0;
                    if (seg_dec == 4'd5) begin
                        seg_dec <= 4'd0;
                        if (min_uni == 4'd9) begin
                            min_uni <= 4'd0;
                            if (min_dec == 4'd5) begin
                                min_dec <= 4'd0;
                                //! Rollover de hora: 23:59:59 → 00:00:00
                                if (hora_dec == 4'd2 && hora_uni == 4'd3) begin
                                    hora_dec <= 4'd0; hora_uni <= 4'd0;
                                end else if (hora_uni == 4'd9) begin
                                    hora_uni <= 4'd0;
                                    hora_dec <= hora_dec + 4'd1;
                                end else
                                    hora_uni <= hora_uni + 4'd1;
                            end else
                                min_dec <= min_dec + 4'd1;
                        end else
                            min_uni <= min_uni + 4'd1;
                    end else
                        seg_dec <= seg_dec + 4'd1;
                end else
                    seg_uni <= seg_uni + 4'd1;
            end

        end
    end

endmodule