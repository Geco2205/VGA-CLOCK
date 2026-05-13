`timescale 1ns / 1ps
`default_nettype none

//! @title tb_image_generator
//! @brief Testbench para validar el barrido y la escritura de image_generator.v.
//!
//! Este banco de pruebas revisa que el generador de imagen active la escritura
//! hacia VRAM, produzca direcciones consecutivas y reinicie correctamente el
//! barrido al final del framebuffer de 640x480.
//!
//! El test no intenta validar visualmente cada color del diseño, porque eso
//! corresponde a una revisión gráfica. En cambio, verifica las señales críticas
//! para integración: wr_en, wr_addr y wr_data.
module tb_image_generator;

    //! Constantes de pantalla usadas por el generador.
    localparam SCREEN_W = 640;
    localparam SCREEN_H = 480;
    localparam [18:0] LAST_ADDR = (SCREEN_W * SCREEN_H) - 1;

    //! Estados usados por hour_control.v y blink_ctrl.v.
    localparam SET_HOURS = 2'd0;
    localparam SET_MIN   = 2'd1;
    localparam RUN       = 2'd2;

    //! Reloj y reset del sistema.
    reg clk = 1'b0;
    reg rst = 1'b1;

    //! Dígitos BCD de prueba para mostrar 12:34:56.
    reg [3:0] hora_dec = 4'd1;
    reg [3:0] hora_uni = 4'd2;
    reg [3:0] min_dec  = 4'd3;
    reg [3:0] min_uni  = 4'd4;
    reg [3:0] seg_dec  = 4'd5;
    reg [3:0] seg_uni  = 4'd6;

    //! Estado inicial de operación.
    reg [1:0] estado = RUN;

    //! Señales de escritura generadas por image_generator.v.
    wire [18:0] wr_addr;
    wire [11:0] wr_data;
    wire        wr_en;

    //! Señales de interfaz VGA presentes en el módulo, no usadas por el barrido interno actual.
    reg [9:0] pixel_x  = 10'd0;
    reg [8:0] pixel_y  = 9'd0;
    reg       video_on = 1'b1;

    //! Variables de control del testbench.
    integer i;
    integer errors;

    //! Reloj de 100 MHz: periodo de 10 ns.
    always #5 clk = ~clk;

    //! Instancia del módulo bajo prueba.
    image_generator dut (
        .clk     (clk),
        .rst     (rst),
        .hora_dec(hora_dec),
        .hora_uni(hora_uni),
        .min_dec (min_dec),
        .min_uni (min_uni),
        .seg_dec (seg_dec),
        .seg_uni (seg_uni),
        .estado  (estado),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .wr_en   (wr_en),
        .pixel_x (pixel_x),
        .pixel_y (pixel_y),
        .video_on(video_on)
    );

    //! Revisa que wr_data tenga un valor definido.
    function has_unknown;
        input [11:0] value;
        begin
            has_unknown = (^value === 1'bx);
        end
    endfunction

    //! Verifica una dirección esperada en la salida de escritura.
    task check_write_addr;
        input [18:0] expected_addr;
        begin
            @(posedge clk);
            #1;

            if (wr_en !== 1'b1) begin
                $display("[TB_IMG ERROR] wr_en no está activo. tiempo=%0t", $time);
                errors = errors + 1;
            end

            if (wr_addr !== expected_addr) begin
                $display("[TB_IMG ERROR] wr_addr esperado=%0d obtenido=%0d tiempo=%0t",
                         expected_addr, wr_addr, $time);
                errors = errors + 1;
            end

            if (has_unknown(wr_data)) begin
                $display("[TB_IMG ERROR] wr_data tiene bits indefinidos en addr=%0d tiempo=%0t",
                         wr_addr, $time);
                errors = errors + 1;
            end
        end
    endtask

    //! Secuencia principal de prueba.
    initial begin
        errors = 0;

        $dumpfile("tb_image_generator.vcd");
        $dumpvars(0, tb_image_generator);

        //! Mantiene reset activo durante varios ciclos.
        repeat (4) @(posedge clk);
        #1;

        if (wr_en !== 1'b0 || wr_addr !== 19'd0 || wr_data !== 12'd0) begin
            $display("[TB_IMG ERROR] Estado de reset inesperado: wr_en=%b wr_addr=%0d wr_data=%h",
                     wr_en, wr_addr, wr_data);
            errors = errors + 1;
        end else begin
            $display("[TB_IMG OK] Reset inicial correcto.");
        end

        //! Libera reset en flanco negativo para evitar carreras con el DUT.
        @(negedge clk);
        rst = 1'b0;

        //! Verifica direcciones consecutivas al inicio del framebuffer.
        for (i = 0; i < 20; i = i + 1) begin
            check_write_addr(i);
        end
        $display("[TB_IMG OK] Primeras 20 direcciones consecutivas verificadas.");

        //! Continúa hasta cruzar el final de la primera línea visible.
        for (i = 20; i <= 641; i = i + 1) begin
            check_write_addr(i);
        end

        //! Después de escribir la dirección 639, el barrido interno debe pasar a la fila 1.
        if (dut.py !== 9'd1) begin
            $display("[TB_IMG ERROR] py no avanzó a la fila 1. py=%0d tiempo=%0t", dut.py, $time);
            errors = errors + 1;
        end else begin
            $display("[TB_IMG OK] Cruce de línea verificado: el barrido pasó a py=1.");
        end

        //! Cambia el estado de edición y los dígitos para verificar que el generador sigue escribiendo.
        @(negedge clk);
        estado   = SET_HOURS;
        hora_dec = 4'd2;
        hora_uni = 4'd3;
        min_dec  = 4'd5;
        min_uni  = 4'd9;
        seg_dec  = 4'd0;
        seg_uni  = 4'd8;

        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            #1;
            if (wr_en !== 1'b1 || has_unknown(wr_data)) begin
                $display("[TB_IMG ERROR] Escritura inválida luego de cambiar estado. tiempo=%0t", $time);
                errors = errors + 1;
            end
        end
        $display("[TB_IMG OK] Cambio de estado y dígitos no detiene la escritura.");

        //! Prueba rápida del reinicio de frame usando acceso jerárquico solo de simulación.
        //! Esto evita simular 307200 ciclos para llegar al último pixel.
        @(negedge clk);
        dut.px = 10'd638;
        dut.py = 9'd479;

        check_write_addr((LAST_ADDR - 1));
        check_write_addr(LAST_ADDR);

        if (dut.px !== 10'd0 || dut.py !== 9'd0) begin
            $display("[TB_IMG ERROR] El barrido no reinició al final del frame. px=%0d py=%0d",
                     dut.px, dut.py);
            errors = errors + 1;
        end else begin
            $display("[TB_IMG OK] Reinicio del frame verificado en px=0, py=0.");
        end

        check_write_addr(19'd0);

        if (errors == 0) begin
            $display("[TB_IMG PASS] Todas las pruebas finalizaron correctamente.");
        end else begin
            $display("[TB_IMG FAIL] Se detectaron %0d errores.", errors);
        end

        $finish;
    end

endmodule

`default_nettype wire
