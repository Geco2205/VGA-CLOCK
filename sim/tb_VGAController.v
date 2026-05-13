`timescale 1ns / 1ps

//! @title  tb_VGAController - Testbench del controlador VGA
//! @author Gerson Adrián Cordero Zúñiga
//!
//! Verifica el funcionamiento de SyncVGA y VGAController mediante 8 pruebas:
//!   1. Reset:    HSYNC y VSYNC arrancan en 1, RGB en 0
//!   2. pclk_en:  pulsa exactamente 1 de cada 4 ciclos
//!   3. video_en: activo solo en h<640 y v<480
//!   4. RGB = 0 en zona de blanking
//!   5. RGB != 0 en zona visible (VRAM mock devuelve dato)
//!   6. Dirección VRAM: addr = v*640 + h
//!   7. HSYNC: pulso activo-bajo entre pixeles 656-751
//!   8. VSYNC: pulso activo-bajo entre lineas 490-491
//!
//! La VRAM se simula con un mock que devuelve los 12 bits bajos de la
//! dirección como color, replicando la latencia de 1 ciclo de una BRAM real.

module tb_VGAController;

    // -------------------------------------------------------------------------
    // Parámetros del testbench
    // -------------------------------------------------------------------------

    localparam CLK_PERIOD       = 10; //! Periodo del clock de sistema: 10 ns (100 MHz)
    localparam CYCLES_PER_PIXEL = 4;  //! Ciclos de sistema por pixel (divisor de clock)

    localparam H_VISIBLE = 640; //! Pixeles visibles horizontales
    localparam H_FP      = 16;  //! Front Porch horizontal
    localparam H_SYNC_W  = 96;  //! Ancho del pulso HSYNC
    localparam H_TOTAL   = 800; //! Total pixeles por línea

    localparam V_VISIBLE = 480; //! Líneas visibles verticales
    localparam V_FP      = 10;  //! Front Porch vertical
    localparam V_SYNC_W  = 2;   //! Ancho del pulso VSYNC
    localparam V_TOTAL   = 525; //! Total líneas por frame

    // -------------------------------------------------------------------------
    // Señales del DUT (Device Under Test)
    // -------------------------------------------------------------------------

    reg         clk;       //! Clock de sistema: 100 MHz
    reg         rst;       //! Reset síncrono activo alto
    reg  [11:0] vram_data; //! Dato de color retornado por la VRAM mock
    wire [18:0] vram_addr; //! Dirección de lectura pedida por el DUT
    wire        hsync;     //! Señal HSYNC generada por el DUT
    wire        vsync;     //! Señal VSYNC generada por el DUT
    wire [3:0]  vga_r;     //! Canal rojo generado por el DUT
    wire [3:0]  vga_g;     //! Canal verde generado por el DUT
    wire [3:0]  vga_b;     //! Canal azul generado por el DUT
    wire [9:0]  h_count;   //! Posición horizontal actual del DUT
    wire [9:0]  v_count;   //! Posición vertical actual del DUT
    wire        video_en;  //! Zona visible activa del DUT
    wire        pclk_en;   //! Pixel clock enable del DUT

    // -------------------------------------------------------------------------
    // Variables auxiliares del testbench
    // -------------------------------------------------------------------------

    integer errors;                    //! Contador de pruebas fallidas
    integer i, timeout;                //! Variables de control de loops
    integer pclk_count, cycle_count;   //! Contadores para prueba de pclk_en
    integer hs_start_h, hs_end_h;     //! h_count en flancos de HSYNC
    integer vs_start_v, vs_end_v;     //! v_count en flancos de VSYNC
    integer expected_addr;             //! Dirección VRAM esperada
    reg     hsync_prev, vsync_prev;   //! Valores anteriores para detectar flancos

    // -------------------------------------------------------------------------
    // Instancia del DUT
    // -------------------------------------------------------------------------

    VGAController dut ( //! Device Under Test: VGAController
        .clk       (clk),
        .rst       (rst),
        .vram_data (vram_data),
        .vram_addr (vram_addr),
        .hsync     (hsync),
        .vsync     (vsync),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b),
        .h_count   (h_count),
        .v_count   (v_count),
        .video_en  (video_en),
        .pclk_en   (pclk_en)
    );

    // -------------------------------------------------------------------------
    // Generación de clock: 100 MHz
    // -------------------------------------------------------------------------

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk; //! Invierte el clock cada 5 ns → 100 MHz

    // -------------------------------------------------------------------------
    // VRAM mock: simula latencia de 1 ciclo de la BRAM.
    // Devuelve los 12 bits bajos de la dirección como color de prueba,
    // permitiendo verificar que la dirección calculada es correcta.
    // -------------------------------------------------------------------------

    always @(posedge clk)
        vram_data <= vram_addr[11:0]; //! Latencia 1 ciclo, igual que BRAM síncrona

    // -------------------------------------------------------------------------
    // Tareas auxiliares
    // -------------------------------------------------------------------------

    //! Avanza exactamente n pixeles completos (n * CYCLES_PER_PIXEL ciclos)
    task wait_pixels;
        input integer n;
        integer j;
        begin
            for (j = 0; j < n * CYCLES_PER_PIXEL; j = j + 1)
                @(posedge clk);
        end
    endtask

    //! Espera hasta el inicio de un frame (h=0, v=0) con timeout de seguridad
    task wait_frame_start;
        begin
            timeout = 0;
            while (!((h_count == 0) && (v_count == 0)) && timeout < 3000000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
        end
    endtask

    //! Evalúa una condición e imprime PASS o FAIL con el mensaje dado
    task check;
        input condition;
        input [400:0] msg;
        begin
            if (!condition) begin
                $display("  [FAIL] %s", msg);
                errors = errors + 1;
            end else
                $display("  [PASS] %s", msg);
        end
    endtask

    // -------------------------------------------------------------------------
    // Secuencia de pruebas
    // -------------------------------------------------------------------------

    initial begin
        errors     = 0;
        rst        = 1;
        vram_data  = 12'h000;
        hsync_prev = 1;
        vsync_prev = 1;

        $display("  TB VGAController ");

        // ── TEST 1: Reset ──────────────────────────────────────────────────
        $display("\n[TEST 1] Reset - salidas iniciales");
        repeat(10) @(posedge clk);
        check(hsync == 1'b1,   "HSYNC = 1 (inactivo) durante reset");
        check(vsync == 1'b1,   "VSYNC = 1 (inactivo) durante reset");
        check(vga_r == 4'h0,   "vga_r = 0 durante reset");
        check(vga_g == 4'h0,   "vga_g = 0 durante reset");
        check(vga_b == 4'h0,   "vga_b = 0 durante reset");

        @(posedge clk); rst = 0; @(posedge clk);

        // ── TEST 2: pclk_en pulsa 1 de cada 4 ciclos ──────────────────────
        $display("\n[TEST 2] pclk_en - pulso 1 de cada 4 ciclos");
        pclk_count  = 0;
        cycle_count = 0;
        repeat(40) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (pclk_en) pclk_count = pclk_count + 1;
        end
        check(pclk_count == 10, "pclk_en pulsa 10 veces en 40 ciclos");

        // ── TEST 3: video_en ───────────────────────────────────────────────
        $display("\n[TEST 3] video_en - zona visible vs blanking");
        wait_frame_start;

        wait_pixels(100 * H_TOTAL + 100); // pixel (h=100, v=100)
        check(video_en == 1'b1, "video_en = 1 en (h=100, v=100) zona visible");

        wait_pixels(540); // avanzar a h=640
        check(video_en == 1'b0, "video_en = 0 en (h=640, v=100) blanking H");

        // ── TEST 4: RGB = 0 en blanking ────────────────────────────────────
        $display("\n[TEST 4] RGB = 0 en blanking");
        // 2 pclk_en: 1 para video_en_d, 1 para el registro RGB
        wait_pixels(2);
        $display("  [DEBUG] TEST4: vga_r=%h vga_g=%h vga_b=%h video_en=%b", vga_r, vga_g, vga_b, video_en);
        check((vga_r == 4'h0) && (vga_g == 4'h0) && (vga_b == 4'h0),
              "vga_r/g/b = 0 en zona de blanking horizontal");

        // ── TEST 5: RGB != 0 en zona visible ──────────────────────────────
        $display("\n[TEST 5] RGB != 0 en zona visible");
        wait_frame_start;
        wait_pixels(200 * H_TOTAL + 200); // pixel (h=200, v=200)
        wait_pixels(2);                   // latencia BRAM + video_en_d
        check((vga_r !== 4'h0) || (vga_g !== 4'h0) || (vga_b !== 4'h0),
              "vga_r/g/b != 0 en zona visible (VRAM mock devuelve dato)");

        // ── TEST 6: Dirección VRAM = v*640 + h ────────────────────────────
        $display("\n[TEST 6] Direccion VRAM = v*640 + h");
        wait_frame_start;

        wait_pixels(30 * H_TOTAL + 50); // pixel (h=50, v=30)
        expected_addr = 30 * 640 + 50;  // = 19250
        check(vram_addr == expected_addr,
              "addr correcto en pixel (h=50, v=30): 30*640+50 = 19250");

        wait_pixels((240-30) * H_TOTAL + (320-50)); // pixel (h=320, v=240)
        expected_addr = 240 * 640 + 320;             // = 154240
        check(vram_addr == expected_addr,
              "addr correcto en pixel (h=320, v=240): 240*640+320 = 154240");

        // ── TEST 7: HSYNC en posición correcta ────────────────────────────
        $display("\n[TEST 7] HSYNC - pulso activo-bajo pixeles 656 a 751");
        wait_frame_start;

        hs_start_h = -1;
        hs_end_h   = -1;
        hsync_prev = 1;
        timeout    = 0;

        // Monitorear línea 0 completa buscando flancos de HSYNC
        while (v_count == 0 && timeout < 10000) begin
            @(posedge clk);
            timeout = timeout + 1;
            if (pclk_en) begin
                if (hsync_prev == 1 && hsync == 0) hs_start_h = h_count;
                if (hsync_prev == 0 && hsync == 1) hs_end_h   = h_count;
                hsync_prev = hsync;
            end
        end

        // HSYNC y h_cnt se actualizan con NBA simultáneamente en el mismo posedge.
        // El TB lee h_count ya incrementado (+1) cuando detecta el flanco.
        // → bajada cuando h_count = HS_START + 1 = 657
        // → subida  cuando h_count = HS_END   + 1 = 753
        $display("  [DEBUG] hs_start_h detectado = %0d (esperado 657)", hs_start_h);
        check(hs_start_h == (H_VISIBLE + H_FP + 1),
              "HSYNC baja con h_count=657 (latencia 1 ciclo respecto a HS_START=656)");

        $display("  [DEBUG] hs_end_h detectado   = %0d (esperado 753)", hs_end_h);
        check(hs_end_h == (H_VISIBLE + H_FP + H_SYNC_W + 1),
              "HSYNC sube con h_count=753 (latencia 1 ciclo respecto a HS_END=752)");

        // ── TEST 8: VSYNC en posición correcta ────────────────────────────
        $display("\n[TEST 8] VSYNC - pulso activo-bajo lineas 490 a 491");
        wait_frame_start;

        vs_start_v = -1;
        vs_end_v   = -1;
        vsync_prev = 1;
        timeout    = 0;

        // Monitorear frame completo, muestrear en h=0 de cada línea
        while (timeout < 2200000) begin
            @(posedge clk);
            timeout = timeout + 1;
            if (pclk_en && h_count == 0) begin
                if (vsync_prev == 1 && vsync == 0) vs_start_v = v_count;
                if (vsync_prev == 0 && vsync == 1) vs_end_v   = v_count;
                vsync_prev = vsync;
            end
        end

        // VSYNC y v_cnt se actualizan simultáneamente. El TB muestrea v_count
        // en h_count==0 (post-incremento) → valores detectados con +1 de offset.
        // → bajada cuando v_count = VS_START + 1 = 491
        // → subida  cuando v_count = VS_END   + 1 = 493
        $display("  [DEBUG] vs_start_v detectado = %0d (esperado 491)", vs_start_v);
        check(vs_start_v == (V_VISIBLE + V_FP + 1),
              "VSYNC baja con v_count=491 (latencia 1 ciclo respecto a VS_START=490)");

        $display("  [DEBUG] vs_end_v detectado   = %0d (esperado 493)", vs_end_v);
        check(vs_end_v == (V_VISIBLE + V_FP + V_SYNC_W + 1),
              "VSYNC sube con v_count=493 (latencia 1 ciclo respecto a VS_END=492)");

        // ── Resumen ────────────────────────────────────────────────────────
        $display("\n==============================================");
        if (errors == 0)
            $display("  RESULTADO: TODOS LOS TESTS PASARON :)");
        else
            $display("  RESULTADO: %0d TEST(S) FALLARON - ver waveforms", errors);
        $display("==============================================\n");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout global de seguridad: evita simulación infinita ante bugs
    // -------------------------------------------------------------------------

    initial begin
        #(CLK_PERIOD * 15_000_000); //! Límite de 15 millones de ciclos (~150 ms)
        $display("[ERROR] Timeout global del testbench");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Dump de waveforms para GTKWave o Vivado Waveform Viewer
    // -------------------------------------------------------------------------

    initial begin
        $dumpfile("tb_VGAController.vcd"); //! Archivo de salida de waveforms
        $dumpvars(0, tb_VGAController);    //! Captura todas las señales del módulo
    end

endmodule