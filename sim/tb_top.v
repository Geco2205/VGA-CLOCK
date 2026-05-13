`timescale 1ns/1ps

//! @title  tb_top - Testbench del sistema completo
//! @author Keillin Loaisiga
//!
//! Testbench de integración que verifica el funcionamiento
//! completo del sistema de reloj VGA instanciando el módulo top.
//!
//! Pruebas incluidas:
//!   1. Verificar señales VGA activas tras reset
//!   2. Verificar hora inicial 00:00:00 en modo RUN
//!   3. Ajustar hora a 08:30 con switches y botones
//!   4. Verificar escrituras del image_generator en VRAM
//!   5. Verificar lectura de VRAM por el VGAController
//!   6. Verificar conteo automático de segundos
//!   7. Verificar generación de HSYNC y VSYNC

module tb_top;

    // -------------------------------------------------------------------------
    // Señales del testbench
    // -------------------------------------------------------------------------
    reg        clk;       //! Reloj del sistema: 100 MHz
    reg        rst;       //! Reset activo alto
    reg  [8:0] sw;        //! Switches de ajuste
    reg        btn_c;     //! Botón avanzar estado
    reg        btn_r;     //! Botón retroceder estado
    wire       vga_hsync; //! Señal HSYNC generada por el sistema
    wire       vga_vsync; //! Señal VSYNC generada por el sistema
    wire [3:0] vga_r;     //! Canal rojo VGA
    wire [3:0] vga_g;     //! Canal verde VGA
    wire [3:0] vga_b;     //! Canal azul VGA

    // -------------------------------------------------------------------------
    // Instancia del sistema completo
    // -------------------------------------------------------------------------
    top uut ( //! Sistema completo bajo prueba
        .clk      (clk),
        .rst      (rst),
        .sw       (sw),
        .btn_c    (btn_c),
        .btn_r    (btn_r),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_r    (vga_r),
        .vga_g    (vga_g),
        .vga_b    (vga_b)
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
        $display("  TESTBENCH: Sistema completo (top.v)");
        $display("================================================");

        //! Reset inicial
        rst   = 1;
        sw    = 9'd0;
        btn_c = 0;
        btn_r = 0;
        #200;
        rst = 0;
        #200;

        //! Prueba 1: Verificar señales VGA activas
        $display("\n[PRUEBA 1] Verificar señales VGA activas");
        #1000;
        $display("hsync=%0b vsync=%0b", vga_hsync, vga_vsync);
        $display("vga_r=%0h vga_g=%0h vga_b=%0h", vga_r, vga_g, vga_b);
        if (vga_hsync || vga_vsync)
            $display("Señales VGA activas OK");
        else
            $display("ADVERTENCIA: revisar señales VGA");

        //! Prueba 2: Verificar hora inicial 00:00:00
        $display("\n[PRUEBA 2] Verificar hora inicial 00:00:00");
        #500;
        $display("hora_dec=%0d hora_uni=%0d",
                  uut.hc.hora_dec, uut.hc.hora_uni);
        $display("min_dec=%0d  min_uni=%0d",
                  uut.hc.min_dec,  uut.hc.min_uni);
        $display("seg_dec=%0d  seg_uni=%0d",
                  uut.hc.seg_dec,  uut.hc.seg_uni);
        $display("estado=%0d (esperado 2=RUN)", uut.hc.estado);

        //! Prueba 3: Ajustar hora a 08:30
        $display("\n[PRUEBA 3] Ajustar hora a 08:30");
        btn_r = 1; #500; btn_r = 0; #500;
        btn_r = 1; #500; btn_r = 0; #500;
        sw[8]   = 1;
        sw[7:4] = 4'd0;
        sw[3:0] = 4'd8;
        #500;
        $display("Hora seteada: %0d%0d (esperado 08)",
                  uut.hc.hora_dec, uut.hc.hora_uni);
        btn_c = 1; #500; btn_c = 0; #500;
        sw[7:4] = 4'd3;
        sw[3:0] = 4'd0;
        #500;
        $display("Minutos seteados: %0d%0d (esperado 30)",
                  uut.hc.min_dec, uut.hc.min_uni);
        btn_c = 1; #500; btn_c = 0; #500;
        sw[8] = 0;
        $display("Estado: %0d (esperado 2=RUN)", uut.hc.estado);

        //! Prueba 4: Verificar escrituras del image_generator en VRAM
        $display("\n[PRUEBA 4] Verificar que VRAM recibe escrituras");
        #1000;
        $display("wr_en=%0b  wr_addr=%0d  wr_data=%03h",
                  uut.wr_en, uut.wr_addr, uut.wr_data);
        if (uut.wr_en)
            $display("image_generator escribiendo en VRAM OK");
        else
            $display("ERROR: image_generator no escribe en VRAM");

        //! Prueba 5: Verificar lectura de VRAM por VGAController
        $display("\n[PRUEBA 5] Verificar que VGA lee de VRAM");
        #1000;
        $display("rd_addr=%0d  rd_data=%03h", uut.rd_addr, uut.rd_data);
        $display("vga_r=%0h vga_g=%0h vga_b=%0h", vga_r, vga_g, vga_b);

        //! Prueba 6: Verificar conteo automático de segundos
        $display("\n[PRUEBA 6] Verificar conteo de segundos");
        #50000;
        $display("Hora tras espera: %0d%0d:%0d%0d:%0d%0d",
                  uut.hc.hora_dec, uut.hc.hora_uni,
                  uut.hc.min_dec,  uut.hc.min_uni,
                  uut.hc.seg_dec,  uut.hc.seg_uni);

        //! Prueba 7: Verificar HSYNC y VSYNC generados
        $display("\n[PRUEBA 7] Verificar HSYNC y VSYNC generados");
        #100000;
        $display("hsync=%0b vsync=%0b", vga_hsync, vga_vsync);
        $display("vga_r=%0h vga_g=%0h vga_b=%0h", vga_r, vga_g, vga_b);

        $display("\n================================================");
        $display("  Simulacion sistema completo terminada");
        $display("================================================");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Monitor continuo de señales clave
    // -------------------------------------------------------------------------
    initial begin
        $monitor("t=%0t | hora=%0d%0d:%0d%0d:%0d%0d | wr_en=%0b | hsync=%0b vsync=%0b | rgb=%0h%0h%0h",
                  $time,
                  uut.hc.hora_dec, uut.hc.hora_uni,
                  uut.hc.min_dec,  uut.hc.min_uni,
                  uut.hc.seg_dec,  uut.hc.seg_uni,
                  uut.wr_en,
                  vga_hsync, vga_vsync,
                  vga_r, vga_g, vga_b);
    end

endmodule