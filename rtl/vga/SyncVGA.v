`timescale 1ns / 1ps

//! @title  SyncVGA - Generador de sincronización VGA 640x480 @ 60 Hz
//! @author Gerson Adrián Cordero Zúñiga
//!
//! Genera los contadores horizontal y vertical, las señales HSYNC/VSYNC
//! y el habilitador de zona visible (video_en).
//! El pixel clock se deriva dividiendo el reloj de sistema (100 MHz)
//! entre 4, obteniendo ~25 MHz.
//!
//! Timing VGA 640x480 @ 60 Hz:
//!   Horizontal : 640 visible | 16 FP | 96 sync | 48 BP = 800 total
//!   Vertical   : 480 visible | 10 FP |  2 sync | 33 BP = 525 total
//!   HSYNC activo-bajo: pixeles 656-751
//!   VSYNC activo-bajo: lineas  490-491

module SyncVGA (
    input  wire        clk,      //! Reloj de sistema: 100 MHz (Nexys A7)
    input  wire        rst,      //! Reset síncrono activo alto
    output reg         hsync,    //! Señal HSYNC activo-bajo hacia conector VGA
    output reg         vsync,    //! Señal VSYNC activo-bajo hacia conector VGA
    output wire        video_en, //! 1 cuando el haz está en zona visible (h<640 y v<480)
    output wire        pclk_en,  //! Pulso de habilitación de pixel clock (1 de cada 4 ciclos)
    output wire [9:0]  h_count,  //! Posición horizontal actual del pixel (0-799)
    output wire [9:0]  v_count   //! Posición vertical actual del pixel  (0-524)
);

    // -------------------------------------------------------------------------
    // Parámetros de timing VGA 640x480 @ 60 Hz
    // -------------------------------------------------------------------------

    localparam H_VISIBLE = 640; //! Pixeles visibles por línea horizontal
    localparam H_FP      = 16;  //! Front Porch horizontal
    localparam H_SYNC_W  = 96;  //! Ancho del pulso HSYNC
    localparam H_BP      = 48;  //! Back Porch horizontal
    localparam H_TOTAL   = H_VISIBLE + H_FP + H_SYNC_W + H_BP; //! Total pixeles por línea: 800

    localparam V_VISIBLE = 480; //! Líneas visibles por frame
    localparam V_FP      = 10;  //! Front Porch vertical
    localparam V_SYNC_W  = 2;   //! Ancho del pulso VSYNC
    localparam V_BP      = 33;  //! Back Porch vertical
    localparam V_TOTAL   = V_VISIBLE + V_FP + V_SYNC_W + V_BP; //! Total líneas por frame: 525

    localparam HS_START  = H_VISIBLE + H_FP;            //! Pixel de inicio de HSYNC: 656
    localparam HS_END    = H_VISIBLE + H_FP + H_SYNC_W; //! Pixel de fin de HSYNC: 752
    localparam VS_START  = V_VISIBLE + V_FP;            //! Línea de inicio de VSYNC: 490
    localparam VS_END    = V_VISIBLE + V_FP + V_SYNC_W; //! Línea de fin de VSYNC: 492

    // -------------------------------------------------------------------------
    // Divisor de reloj: 100 MHz → pixel clock enable cada 4 ciclos (~25 MHz)
    // -------------------------------------------------------------------------

    reg [1:0] clk_div; //! Contador de 2 bits para división de clock

    always @(posedge clk) begin: clk_divider
        if (rst)
            clk_div <= 2'd0;
        else
            clk_div <= clk_div + 2'd1;
    end

    assign pclk_en = (clk_div == 2'd3); //! Pulso activo en el último ciclo del divisor

    // -------------------------------------------------------------------------
    // Contadores horizontal y vertical
    // -------------------------------------------------------------------------

    reg [9:0] h_cnt; //! Contador horizontal interno: 0 a H_TOTAL-1
    reg [9:0] v_cnt; //! Contador vertical interno:   0 a V_TOTAL-1

    always @(posedge clk) begin: counters
        if (rst) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else if (pclk_en) begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 10'd0;
                v_cnt <= (v_cnt == V_TOTAL - 1) ? 10'd0 : v_cnt + 10'd1;
            end else begin
                h_cnt <= h_cnt + 10'd1;
            end
        end
    end

    assign h_count  = h_cnt;
    assign v_count  = v_cnt;
    assign video_en = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);

    // -------------------------------------------------------------------------
    // Generación de HSYNC y VSYNC (activos en bajo)
    // -------------------------------------------------------------------------

    always @(posedge clk) begin: sync_gen
        if (rst) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else if (pclk_en) begin
            hsync <= ~((h_cnt >= HS_START) && (h_cnt < HS_END));
            vsync <= ~((v_cnt >= VS_START) && (v_cnt < VS_END));
        end
    end

endmodule