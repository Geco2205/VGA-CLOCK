`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Module      : SyncVGA
// Project     : Controlador VGA con Reloj Digital 
// Description : Generador de sincronización VGA 640x480 @ 60 Hz.
//               Genera los contadores horizontal y vertical, las señales
//               HSYNC/VSYNC y el habilitador de zona visible (video_en).
//               El pixel clock se deriva dividiendo el reloj de sistema
//               (100 MHz) entre 4, obteniendo ~25 MHz.
//
// Timing VGA 640x480 @ 60 Hz:
//   Horizontal : 640 visible | 16 FP | 96 sync | 48 BP  = 800 total
//   Vertical   : 480 visible | 10 FP |  2 sync | 33 BP  = 525 total
//   HSYNC activo-bajo: pixeles 656-751
//   VSYNC activo-bajo: líneas  490-491
//
// Inputs  : clk        - Reloj de sistema (100 MHz, Nexys A7)
//           rst        - Reset síncrono activo alto
// Outputs : hsync      - Señal HSYNC hacia el conector VGA
//           vsync      - Señal VSYNC hacia el conector VGA
//           video_en   - 1 cuando el haz está en zona visible
//           pclk_en    - Pulso de habilitación de pixel clock (1 ciclo cada 4)
//           h_count    - Posición horizontal actual del pixel (0-799)
//           v_count    - Posición vertical actual del pixel  (0-524)
//------------------------------------------------------------------------------

module SyncVGA (
    input  wire        clk,       
    input  wire        rst,      
   
    output reg         hsync,     // HSYNC activo-bajo
    output reg         vsync,     // VSYNC activo-bajo
    output wire        video_en,  // Zona visible activa
    // Pixel clock enable (pulso cada 4 ciclos de sistema)
    output wire        pclk_en,
    output wire [9:0]  h_count,   // Contador horizontal
    output wire [9:0]  v_count    // Contador vertical
);


    // Parámetros de timing VGA 640x480 @ 60 Hz
  
    localparam H_VISIBLE    = 640;
    localparam H_FP         = 16;
    localparam H_SYNC_W     = 96;
    localparam H_BP         = 48;
    localparam H_TOTAL      = H_VISIBLE + H_FP + H_SYNC_W + H_BP; // 800

    localparam V_VISIBLE    = 480;
    localparam V_FP         = 10;
    localparam V_SYNC_W     = 2;
    localparam V_BP         = 33;
    localparam V_TOTAL      = V_VISIBLE + V_FP + V_SYNC_W + V_BP; // 525


    localparam HS_START     = H_VISIBLE + H_FP;               // 656
    localparam HS_END       = H_VISIBLE + H_FP + H_SYNC_W;    // 752
    localparam VS_START     = V_VISIBLE + V_FP;               // 490
    localparam VS_END       = V_VISIBLE + V_FP + V_SYNC_W;    // 492

    //--------------------------------------------------------------------------
    // Divisor de reloj: 100 MHz -> pixel clock enable cada 4 ciclos (~25 MHz)
    
    reg [1:0] clk_div;

    always @(posedge clk) begin
        if (rst)
            clk_div <= 2'd0;
        else
            clk_div <= clk_div + 2'd1;
    end

    assign pclk_en = (clk_div == 2'd3);

    //--------------------------------------------------------------------------
    // Contadores horizontal y vertical
    //--------------------------------------------------------------------------
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always @(posedge clk) begin
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

    //--------------------------------------------------------------------------
    // Generación de HSYNC y VSYNC (activos en bajo)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else if (pclk_en) begin
            hsync <= ~((h_cnt >= HS_START) && (h_cnt < HS_END));
            vsync <= ~((v_cnt >= VS_START) && (v_cnt < VS_END));
        end
    end

endmodule