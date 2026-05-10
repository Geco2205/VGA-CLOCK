`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Testbench : tb_VGAController
// Descripción: Verifica el funcionamiento de SyncVGA y VGAController.
//
// Pruebas realizadas:
//   1. Reset: HSYNC y VSYNC arrancan en 1, RGB en 0
//   2. pclk_en: pulsa exactamente 1 de cada 4 ciclos
//   3. video_en: activo solo en h<640 y v<480
//   4. RGB = 0 en zona de blanking
//   5. RGB != 0 en zona visible (VRAM mock devuelve dato)
//   6. Direccion VRAM: addr = v*640 + h
//   7. HSYNC: pulso activo-bajo entre pixeles 656-751
//   8. VSYNC: pulso activo-bajo entre lineas 490-491
//
//------------------------------------------------------------------------------

module tb_VGAController;

    //--------------------------------------------------------------------------
    // Parametros
    //--------------------------------------------------------------------------
    localparam CLK_PERIOD       = 10; // 100 MHz → periodo 10 ns
    localparam CYCLES_PER_PIXEL = 4;  // divisor de clock interno

    localparam H_VISIBLE = 640;
    localparam H_FP      = 16;
    localparam H_SYNC_W  = 96;
    localparam H_TOTAL   = 800;

    localparam V_VISIBLE = 480;
    localparam V_FP      = 10;
    localparam V_SYNC_W  = 2;
    localparam V_TOTAL   = 525;

    //--------------------------------------------------------------------------
    // Señales del DUT
    //--------------------------------------------------------------------------
    reg         clk;
    reg         rst;
    reg  [11:0] vram_data;
    wire [18:0] vram_addr;
    wire        hsync, vsync;
    wire [3:0]  vga_r, vga_g, vga_b;
    wire [9:0]  h_count, v_count;
    wire        video_en;
    wire        pclk_en;

    //--------------------------------------------------------------------------
    // Variables auxiliares
    integer errors;
    integer i, timeout;
    integer pclk_count, cycle_count;
    integer hs_start_h, hs_end_h;
    integer vs_start_v, vs_end_v;
    integer expected_addr;
    reg     hsync_prev, vsync_prev;

    //--------------------------------------------------------------------------
    // Instancia del DUT
    VGAController dut (
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

    //--------------------------------------------------------------------------
    // Clock 100 MHz
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //--------------------------------------------------------------------------
    // VRAM mock: simula latencia de 1 ciclo de la BRAM.
    // Devuelve los 12 bits bajos de la dirección como color de prueba.
    // Así se puede verificar que la dirección que llega es correcta.
    //--------------------------------------------------------------------------
    always @(posedge clk)
        vram_data <= vram_addr[11:0];

    //--------------------------------------------------------------------------
    // Tareas auxiliares
    //--------------------------------------------------------------------------

    // Avanzar exactamente n pixeles (n * 4 ciclos de sistema)
    task wait_pixels;
        input integer n;
        integer j;
        begin
            for (j = 0; j < n * CYCLES_PER_PIXEL; j = j + 1)
                @(posedge clk);
        end
    endtask

    // Esperar hasta inicio de frame (h=0, v=0) con timeout de seguridad
    task wait_frame_start;
        begin
            timeout = 0;
            while (!((h_count == 0) && (v_count == 0)) && timeout < 3000000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
        end
    endtask

    // Reportar resultado de un test
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

    //--------------------------------------------------------------------------
    // SECUENCIA DE PRUEBAS
    //--------------------------------------------------------------------------
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

        // pixel (100, 100) → zona visible
        wait_pixels(100 * H_TOTAL + 100);
        check(video_en == 1'b1, "video_en = 1 en (h=100, v=100) zona visible");

        // pixel (640, 100) → primer pixel de blanking horizontal
        wait_pixels(540); // 640 - 100 = 540
        check(video_en == 1'b0, "video_en = 0 en (h=640, v=100) blanking H");

        // ── TEST 4: RGB = 0 en blanking ────────────────────────────────────
        $display("\n[TEST 4] RGB = 0 en blanking");
        // Esperar 1 pixel completo (4 ciclos de sistema) para garantizar
        // que video_en_d se actualice en el siguiente pclk_en
        wait_pixels(2); // 2 pclk_en: 1 para video_en_d, 1 para registro RGB
        $display("  [DEBUG] TEST4: vga_r=%h vga_g=%h vga_b=%h video_en=%b", vga_r, vga_g, vga_b, video_en);
        check((vga_r == 4'h0) && (vga_g == 4'h0) && (vga_b == 4'h0),
              "vga_r/g/b = 0 en zona de blanking horizontal");

        // ── TEST 5: RGB != 0 en zona visible ──────────────────────────────
        $display("\n[TEST 5] RGB != 0 en zona visible");
        wait_frame_start;
        wait_pixels(200 * H_TOTAL + 200); // pixel (200, 200)
        wait_pixels(2);                   // esperar 2 pclk_en por latencia BRAM + video_en_d
        check((vga_r !== 4'h0) || (vga_g !== 4'h0) || (vga_b !== 4'h0),
              "vga_r/g/b != 0 en zona visible (VRAM mock devuelve dato)");

        // ── TEST 6: Dirección VRAM = v*640 + h ────────────────────────────
        $display("\n[TEST 6] Direccion VRAM = v*640 + h");
        wait_frame_start;

        // pixel (50, 30)
        wait_pixels(30 * H_TOTAL + 50);
        expected_addr = 30 * 640 + 50; // = 19250
        check(vram_addr == expected_addr,
              "addr correcto en pixel (h=50, v=30): 30*640+50 = 19250");

        // pixel (320, 240) - centro de pantalla
        wait_pixels((240-30) * H_TOTAL + (320-50));
        expected_addr = 240 * 640 + 320; // = 154240
        check(vram_addr == expected_addr,
              "addr correcto en pixel (h=320, v=240): 240*640+320 = 154240");

        // ── TEST 7: HSYNC en posición correcta ────────────────────────────
        $display("\n[TEST 7] HSYNC - pulso activo-bajo pixeles 656 a 751");
        wait_frame_start;

        hs_start_h = -1;
        hs_end_h   = -1;
        hsync_prev = 1;
        timeout    = 0;

        // Monitorear línea 0 completa
        while (v_count == 0 && timeout < 10000) begin
            @(posedge clk);
            timeout = timeout + 1;
            if (pclk_en) begin
                if (hsync_prev == 1 && hsync == 0) hs_start_h = h_count;
                if (hsync_prev == 0 && hsync == 1) hs_end_h   = h_count;
                hsync_prev = hsync;
            end
        end

        // Los registros de HSYNC y h_cnt se actualizan simultáneamente
        // con NBA en el mismo posedge. El TB lee h_count ya incrementado (+1).
        // → flanco de bajada ocurre cuando h_count = HS_START + 1 = 657
        // → flanco de subida ocurre cuando h_count = HS_END   + 1 = 753
        
        check(hs_start_h == (H_VISIBLE + H_FP + 1),
              "HSYNC baja con h_count=657 (latencia 1 ciclo respecto a HS_START=656)");
        
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

        // v_cnt también se incrementa simultáneamente con el cambio de VSYNC.
        // El TB muestrea v_count en h_count==0 (ya post-incremento).
        // Cuando v_cnt=490 y h_cnt=799 (fin de línea): VSYNC baja y v_cnt pasa a 491.
        // El TB ve v_count=491 cuando detecta el flanco en h_count=0.
        // → VSYNC baja con v_count = VS_START + 1 = 491
        // → VSYNC sube con v_count = VS_END   + 1 = 493
   
        check(vs_start_v == (V_VISIBLE + V_FP + 1),
              "VSYNC baja con v_count=491 (latencia 1 ciclo respecto a VS_START=490)");
        check(vs_end_v == (V_VISIBLE + V_FP + V_SYNC_W + 1),
              "VSYNC sube con v_count=493 (latencia 1 ciclo respecto a VS_END=492)");

        // ── Resumen ────────────────────────────────────────────────────────
        $display("\n==============================================");
        if (errors == 0)
            $display("   TESTS PASADOS)");
        else
            $display("  RESULTADO: %0d TEST(S) FALLARON - ver waveforms", errors);
        $display("==============================================\n");

        $finish;
    end

    //--------------------------------------------------------------------------
    // Timeout global de seguridad
    //--------------------------------------------------------------------------
    initial begin
        #(CLK_PERIOD * 15_000_000);
        $display("[ERROR] Timeout global del testbench");
        $finish;
    end

    //--------------------------------------------------------------------------
    // Dump de waveforms (para GTKWave o Vivado Waveform Viewer)
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_VGAController.vcd");
        $dumpvars(0, tb_VGAController);
    end

endmodule