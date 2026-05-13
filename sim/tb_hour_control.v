`timescale 1ns/1ps

//! @title  tb_hour_control - Testbench del módulo hour_control
//! @author Keillin Loaisiga
//!
//! Testbench que verifica el funcionamiento del módulo hour_control
//! de forma modular, incluyendo la máquina de estados, el ajuste
//! de hora con switches y el conteo automático de tiempo.
//!
//! Pruebas incluidas:
//!   1. Estado inicial: RUN, hora 00:00:00
//!   2. Retroceder a SET_HOURS con BTNR
//!   3. Ajustar hora a 12 con switches
//!   4. Avanzar a SET_MIN y ajustar minutos a 30
//!   5. Avanzar a RUN y verificar conteo automático
//!   6. Verificar límite 23:59:59 → 00:00:00
//!   7. Retroceder estados con BTNR desde RUN

module tb_hour_control;

    // -------------------------------------------------------------------------
    // Señales del testbench
    // -------------------------------------------------------------------------
    reg        clk;      //! Reloj del sistema: 100 MHz
    reg        rst;      //! Reset activo alto
    reg  [8:0] sw;       //! Switches: SW[8]=habilita ajuste, SW[7:0]=valor
    reg        btn_c;    //! Botón avanzar estado
    reg        btn_r;    //! Botón retroceder estado
    wire [3:0] hora_dec; //! Decenas de la hora
    wire [3:0] hora_uni; //! Unidades de la hora
    wire [3:0] min_dec;  //! Decenas de los minutos
    wire [3:0] min_uni;  //! Unidades de los minutos
    wire [3:0] seg_dec;  //! Decenas de los segundos
    wire [3:0] seg_uni;  //! Unidades de los segundos
    wire [1:0] estado;   //! Estado actual: 0=SET_HOURS, 1=SET_MIN, 2=RUN

    // -------------------------------------------------------------------------
    // Instancia del módulo bajo prueba
    // -------------------------------------------------------------------------
    hour_control uut ( //! Módulo hour_control bajo prueba
        .clk     (clk),
        .rst     (rst),
        .sw      (sw),
        .btn_c   (btn_c),
        .btn_r   (btn_r),
        .hora_dec(hora_dec),
        .hora_uni(hora_uni),
        .min_dec (min_dec),
        .min_uni (min_uni),
        .seg_dec (seg_dec),
        .seg_uni (seg_uni),
        .estado  (estado)
    );

    // -------------------------------------------------------------------------
    // Generador de reloj: 100 MHz (periodo 10 ns)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Secuencia de pruebas
    // -------------------------------------------------------------------------
    initial begin
        $display("================================================");
        $display("  TESTBENCH: hour_control (modular)");
        $display("================================================");

        //! Reset inicial
        rst = 1; sw = 9'd0; btn_c = 0; btn_r = 0;
        #100;
        rst = 0;
        #100;

        //! Prueba 1: Estado inicial
        $display("\n[PRUEBA 1] Estado inicial");
        $display("Estado: %0d (esperado 2=RUN)", estado);
        $display("Hora: %0d%0d:%0d%0d:%0d%0d (esperado 00:00:00)",
                  hora_dec, hora_uni, min_dec, min_uni, seg_dec, seg_uni);

        //! Prueba 2: Retroceder a SET_HOURS con BTNR
        $display("\n[PRUEBA 2] Retroceder a SET_HOURS con BTNR");
        btn_r = 1; #500; btn_r = 0; #500;
        $display("Estado: %0d (esperado 1=SET_MIN)", estado);
        btn_r = 1; #500; btn_r = 0; #500;
        $display("Estado: %0d (esperado 0=SET_HOURS)", estado);

        //! Prueba 3: Ajustar hora a 12 con switches
        $display("\n[PRUEBA 3] Ajustar hora a 12 con switches");
        sw[8]   = 1;
        sw[7:4] = 4'd1;
        sw[3:0] = 4'd2;
        #500;
        $display("Hora: %0d%0d (esperado 12)", hora_dec, hora_uni);

        //! Prueba 4: Avanzar a SET_MIN y ajustar a 30
        $display("\n[PRUEBA 4] Avanzar a SET_MIN y ajustar a 30");
        btn_c = 1; #500; btn_c = 0; #500;
        $display("Estado: %0d (esperado 1=SET_MIN)", estado);
        sw[7:4] = 4'd3;
        sw[3:0] = 4'd0;
        #500;
        $display("Minutos: %0d%0d (esperado 30)", min_dec, min_uni);

        //! Prueba 5: Avanzar a RUN y verificar conteo
        $display("\n[PRUEBA 5] Avanzar a RUN y verificar conteo");
        btn_c = 1; #500; btn_c = 0; #500;
        sw[8] = 0;
        $display("Estado: %0d (esperado 2=RUN)", estado);
        #50000;
        $display("Hora tras conteo: %0d%0d:%0d%0d:%0d%0d",
                  hora_dec, hora_uni, min_dec, min_uni, seg_dec, seg_uni);

        //! Prueba 6: Verificar límite 23:59:59 → 00:00:00
        $display("\n[PRUEBA 6] Verificar limite 23:59:59 -> 00:00:00");
        rst = 1; #20; rst = 0;
        btn_r = 1; #500; btn_r = 0; #500;
        btn_r = 1; #500; btn_r = 0; #500;
        sw[8]   = 1;
        sw[7:4] = 4'd2; sw[3:0] = 4'd3;
        #200;
        btn_c = 1; #500; btn_c = 0; #500;
        sw[7:4] = 4'd5; sw[3:0] = 4'd9;
        #200;
        btn_c = 1; #500; btn_c = 0; #500;
        sw[8] = 0;
        #60000;
        $display("Hora cerca del limite: %0d%0d:%0d%0d:%0d%0d",
                  hora_dec, hora_uni, min_dec, min_uni, seg_dec, seg_uni);

        //! Prueba 7: Retroceder estados con BTNR desde RUN
        $display("\n[PRUEBA 7] Retroceder estados con BTNR desde RUN");
        btn_r = 1; #500; btn_r = 0; #500;
        $display("Estado: %0d (esperado 1=SET_MIN)", estado);
        btn_r = 1; #500; btn_r = 0; #500;
        $display("Estado: %0d (esperado 0=SET_HOURS)", estado);

        $display("\n================================================");
        $display("  Simulacion completa");
        $display("================================================");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Monitor continuo de señales
    // -------------------------------------------------------------------------
    initial begin
        $monitor("t=%0t | estado=%0d | %0d%0d:%0d%0d:%0d%0d",
                  $time, estado,
                  hora_dec, hora_uni,
                  min_dec,  min_uni,
                  seg_dec,  seg_uni);
    end

endmodule