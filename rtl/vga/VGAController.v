`timescale 1ns / 1ps

//! @title  VGAController - Controlador VGA completo
//! @author Gerson Cordero Zúñiga
//!
//! Controlador VGA para resolución 640x480 @ 60 Hz sobre la Nexys A7.
//! Se divide internamente en tres bloques:
//!   1. SyncVGA    - generadores de sincronización (H/V counters, HSYNC, VSYNC, video_en)
//!   2. Dirección VRAM - calcula la dirección de lectura a partir de (h_count, v_count)
//!   3. Salida RGB - en zona visible saca el dato de VRAM; fuera fuerza negro
//!
//! La VRAM es una memoria lineal de 307200 posiciones (640x480) con datos de
//! 12 bits de color {R[3:0], G[3:0], B[3:0]}.
//! La dirección se calcula como: addr = v*640 + h
//! usando solo shifts y un sumador: 640 = 2^9 + 2^7
//!
//! La BRAM tiene 1 ciclo de latencia de lectura. Se registra video_en (video_en_d)
//! para alinear el enmascaramiento RGB con el dato que ya salió de la BRAM.

module VGAController (
    input  wire        clk,       //! Reloj de sistema: 100 MHz (Nexys A7)
    input  wire        rst,       //! Reset síncrono activo alto

    input  wire [11:0] vram_data, //! Dato de color leído de VRAM: {R[3:0], G[3:0], B[3:0]}
    output wire [18:0] vram_addr, //! Dirección de lectura de VRAM (19 bits, 0 a 307199)

    output wire        hsync,     //! Señal HSYNC activo-bajo hacia conector VGA
    output wire        vsync,     //! Señal VSYNC activo-bajo hacia conector VGA
    output reg  [3:0]  vga_r,     //! Canal rojo de salida (4 bits)
    output reg  [3:0]  vga_g,     //! Canal verde de salida (4 bits)
    output reg  [3:0]  vga_b,     //! Canal azul de salida (4 bits)

    output wire [9:0]  h_count,   //! Coordenada X del pixel actual (0-799), para Image Generator
    output wire [9:0]  v_count,   //! Coordenada Y del pixel actual (0-524), para Image Generator
    output wire        video_en,  //! 1 = zona visible (h<640 y v<480)
    output wire        pclk_en    //! Pixel clock enable: pulso 1 de cada 4 ciclos de sistema
);

    // -------------------------------------------------------------------------
    // Bloque 1: Instancia del generador de sincronización
    // -------------------------------------------------------------------------

    wire        sync_video_en; //! video_en interno desde SyncVGA
    wire        pclk;          //! pclk_en interno desde SyncVGA
    wire [9:0]  h_cnt, v_cnt;  //! Contadores internos desde SyncVGA

    SyncVGA u_sync ( //! Instancia del generador de sincronización VGA
        .clk      (clk),
        .rst      (rst),
        .hsync    (hsync),
        .vsync    (vsync),
        .video_en (sync_video_en),
        .pclk_en  (pclk),
        .h_count  (h_cnt),
        .v_count  (v_cnt)
    );

    assign h_count  = h_cnt;
    assign v_count  = v_cnt;
    assign video_en = sync_video_en;
    assign pclk_en  = pclk;

    // -------------------------------------------------------------------------
    // Bloque 2: Lógica de dirección VRAM
    //
    // addr = v * 640 + h
    // 640 = 2^9 + 2^7 → sin multiplicador:
    // addr = (v << 9) + (v << 7) + h
    // -------------------------------------------------------------------------

    wire [18:0] addr_calc; //! Dirección calculada combinacionalmente

    assign addr_calc = ({9'd0, v_cnt} << 9)  // v * 512
                     + ({9'd0, v_cnt} << 7)  // v * 128 → v * 640
                     + {9'd0, h_cnt};         // + h

    assign vram_addr = addr_calc;

    // -------------------------------------------------------------------------
    // Bloque 3: Lógica de salida RGB
    // -------------------------------------------------------------------------

    reg video_en_d; //! video_en retardado 1 ciclo, alineado con latencia de BRAM

    always @(posedge clk) begin: video_en_delay
        if (rst)
            video_en_d <= 1'b0;
        else if (pclk)
            video_en_d <= sync_video_en;
    end

    always @(posedge clk) begin: rgb_output
        if (rst) begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end else if (pclk) begin
            if (video_en_d) begin
                vga_r <= vram_data[11:8]; //! Componente roja del pixel
                vga_g <= vram_data[7:4];  //! Componente verde del pixel
                vga_b <= vram_data[3:0];  //! Componente azul del pixel
            end else begin
                vga_r <= 4'h0; //! Negro en zona de blanking
                vga_g <= 4'h0;
                vga_b <= 4'h0;
            end
        end
    end

endmodule