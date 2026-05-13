`timescale 1ns / 1ps
`default_nettype none

//! @title tb_vram
//! @brief Testbench autocontenible para validar la memoria de video vram.v.
//!
//! Este banco de pruebas verifica el comportamiento básico de la VRAM usada
//! como framebuffer del sistema VGA. Se revisa escritura síncrona, lectura
//! síncrona y retención del dato de salida cuando rd_en está desactivado.
//!
//! El test usa una profundidad pequeña para acelerar la simulación. El módulo
//! probado conserva la misma interfaz y el mismo comportamiento que la VRAM
//! usada en el proyecto, pero con menos posiciones de memoria.
module tb_vram;

    //! Ancho de dato usado por el proyecto para RGB444.
    localparam DATA_WIDTH = 12;

    //! Ancho de dirección reducido para esta simulación.
    localparam ADDR_WIDTH = 4;

    //! Profundidad reducida: 16 posiciones de memoria.
    localparam DEPTH = 16;

    //! Señales de reloj para los puertos de escritura y lectura.
    reg wr_clk = 1'b0;
    reg rd_clk = 1'b0;

    //! Señales del puerto de escritura.
    reg                  wr_en   = 1'b0;
    reg [ADDR_WIDTH-1:0] wr_addr = {ADDR_WIDTH{1'b0}};
    reg [DATA_WIDTH-1:0] wr_data = {DATA_WIDTH{1'b0}};

    //! Señales del puerto de lectura.
    reg                  rd_en   = 1'b0;
    reg [ADDR_WIDTH-1:0] rd_addr = {ADDR_WIDTH{1'b0}};
    wire [DATA_WIDTH-1:0] rd_data;

    //! Contador de errores del testbench.
    integer errors;

    //! Reloj de escritura: periodo de 10 ns, equivalente a 100 MHz.
    always #5 wr_clk = ~wr_clk;

    //! Reloj de lectura con periodo diferente para probar independencia de puertos.
    always #7 rd_clk = ~rd_clk;

    //! Instancia del módulo bajo prueba.
    vram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEPTH     (DEPTH)
    ) dut (
        .wr_clk (wr_clk),
        .rd_clk (rd_clk),
        .wr_en  (wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .rd_en  (rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data)
    );

    //! Escribe un dato en una dirección de la VRAM.
    task write_pixel;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(negedge wr_clk);
            wr_en   = 1'b1;
            wr_addr = addr;
            wr_data = data;
            @(posedge wr_clk);
            #1;
            wr_en = 1'b0;
        end
    endtask

    //! Lee una dirección y compara el dato obtenido con el valor esperado.
    task read_and_check;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] expected;
        begin
            @(negedge rd_clk);
            rd_en   = 1'b1;
            rd_addr = addr;
            @(posedge rd_clk);
            #1;

            if (rd_data !== expected) begin
                $display("[TB_VRAM ERROR] addr=%0d esperado=%h obtenido=%h tiempo=%0t",
                         addr, expected, rd_data, $time);
                errors = errors + 1;
            end else begin
                $display("[TB_VRAM OK] addr=%0d dato=%h tiempo=%0t", addr, rd_data, $time);
            end

            rd_en = 1'b0;
        end
    endtask

    //! Revisa que rd_data mantenga su valor cuando rd_en está en cero.
    task check_read_hold;
        input [DATA_WIDTH-1:0] expected_hold;
        begin
            @(negedge rd_clk);
            rd_en   = 1'b0;
            rd_addr = 4'd0;
            @(posedge rd_clk);
            #1;

            if (rd_data !== expected_hold) begin
                $display("[TB_VRAM ERROR] rd_data no se mantuvo. esperado=%h obtenido=%h tiempo=%0t",
                         expected_hold, rd_data, $time);
                errors = errors + 1;
            end else begin
                $display("[TB_VRAM OK] rd_data se mantiene cuando rd_en=0. dato=%h", rd_data);
            end
        end
    endtask

    //! Secuencia principal de prueba.
    initial begin
        errors = 0;

        $dumpfile("tb_vram.vcd");
        $dumpvars(0, tb_vram);

        //! Espera inicial para estabilizar señales.
        repeat (3) @(posedge wr_clk);

        //! Escrituras básicas con colores RGB444 representativos.
        write_pixel(4'd0,  12'hF00); // rojo
        write_pixel(4'd1,  12'h0F0); // verde
        write_pixel(4'd2,  12'h00F); // azul
        write_pixel(4'd15, 12'hFFF); // blanco, última dirección válida del test

        //! Lecturas síncronas. El dato aparece después del flanco de rd_clk.
        read_and_check(4'd0,  12'hF00);
        read_and_check(4'd1,  12'h0F0);
        read_and_check(4'd2,  12'h00F);
        read_and_check(4'd15, 12'hFFF);

        //! Verifica que rd_data no cambie si rd_en está desactivado.
        check_read_hold(12'hFFF);

        if (errors == 0) begin
            $display("[TB_VRAM PASS] Todas las pruebas finalizaron correctamente.");
        end else begin
            $display("[TB_VRAM FAIL] Se detectaron %0d errores.", errors);
        end

        $finish;
    end

endmodule

`default_nettype wire
