`timescale 1ns / 1ps

//! @title  top - Módulo de integración del sistema de reloj VGA
//! @author Keillin Loaisiga
//!
//! Módulo top que integra los cuatro bloques principales del
//! sistema de reloj digital con salida VGA para la Nexys A7.
//!
//! Bloques integrados:
//!   - Bloque 1: hour_control   - control de hora y máquina de estados
//!   - Bloque 2: image_generator - generación de imagen en VRAM
//!   - Bloque 3: vram            - memoria de video dual-port (BRAM)
//!   - Bloque 4: VGAController   - sincronización VGA y salida RGB
//!
//! Flujo de datos:
//!   hour_control → image_generator → vram → VGAController → VGA

module top (
    input  wire        clk,       //! Reloj del sistema: 100 MHz (Nexys A7)
    input  wire        rst,       //! Reset síncrono activo alto
    input  wire [8:0]  sw,        //! Switches: SW[8]=habilita ajuste, SW[7:0]=valor
    input  wire        btn_c,     //! Botón central: avanza estado
    input  wire        btn_r,     //! Botón derecho: retrocede estado
    output wire        vga_hsync, //! Señal HSYNC hacia conector VGA
    output wire        vga_vsync, //! Señal VSYNC hacia conector VGA
    output wire [3:0]  vga_r,     //! Canal rojo VGA (4 bits)
    output wire [3:0]  vga_g,     //! Canal verde VGA (4 bits)
    output wire [3:0]  vga_b      //! Canal azul VGA (4 bits)
);

    // -------------------------------------------------------------------------
    // Señales internas Bloque 1 → Bloque 2
    // -------------------------------------------------------------------------

    wire [3:0] hora_dec; //! Decenas de la hora
    wire [3:0] hora_uni; //! Unidades de la hora
    wire [3:0] min_dec;  //! Decenas de los minutos
    wire [3:0] min_uni;  //! Unidades de los minutos
    wire [3:0] seg_dec;  //! Decenas de los segundos
    wire [3:0] seg_uni;  //! Unidades de los segundos
    wire [1:0] estado;   //! Estado actual: 0=SET_HOURS, 1=SET_MIN, 2=RUN

    // -------------------------------------------------------------------------
    // Señales internas Bloque 2 → Bloque 3
    // -------------------------------------------------------------------------

    wire [18:0] wr_addr; //! Dirección de escritura en VRAM
    wire [11:0] wr_data; //! Dato de color a escribir en VRAM {R,G,B}
    wire        wr_en;   //! Habilitador de escritura en VRAM

    // -------------------------------------------------------------------------
    // Señales internas Bloque 3 → Bloque 4
    // -------------------------------------------------------------------------

    wire [18:0] rd_addr; //! Dirección de lectura de VRAM
    wire [11:0] rd_data; //! Dato de color leído de VRAM {R,G,B}

    // -------------------------------------------------------------------------
    // Señales internas Bloque 4 → Bloque 2
    // -------------------------------------------------------------------------

    wire [9:0] h_count;  //! Coordenada X del pixel actual (0-799)
    wire [9:0] v_count;  //! Coordenada Y del pixel actual (0-524)
    wire       video_en; //! 1 = zona visible (h<640 y v<480)
    wire       pclk_en;  //! Pixel clock enable: pulso 1 de cada 4 ciclos

    // -------------------------------------------------------------------------
    // Bloque 1: hour_control
    // -------------------------------------------------------------------------

    hour_control hc ( //! Controla la hora y maneja la máquina de estados
        .clk     (clk),
        .rst     (rst),
        .sw      (sw),
        .btn_c   (btn_c),
        .btn_r   (btn_r),
        .hora_dec(hora_dec), .hora_uni(hora_uni),
        .min_dec (min_dec),  .min_uni (min_uni),
        .seg_dec (seg_dec),  .seg_uni (seg_uni),
        .estado  (estado)
    );

    // -------------------------------------------------------------------------
    // Bloque 2: image_generator
    // -------------------------------------------------------------------------

    image_generator ig ( //! Genera el contenido visual y lo escribe en VRAM
        .clk     (clk),
        .rst     (rst),
        .hora_dec(hora_dec), .hora_uni(hora_uni),
        .min_dec (min_dec),  .min_uni (min_uni),
        .seg_dec (seg_dec),  .seg_uni (seg_uni),
        .estado  (estado),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .wr_en   (wr_en),
        .pixel_x (h_count[9:0]),
        .pixel_y (v_count[8:0]),
        .video_on(video_en)
    );

    // -------------------------------------------------------------------------
    // Bloque 3: vram
    // -------------------------------------------------------------------------

    vram #( //! Memoria de video dual-port inferida como BRAM
        .DATA_WIDTH(12),   //! 12 bits por pixel: {R[3:0], G[3:0], B[3:0]}
        .ADDR_WIDTH(19),   //! 19 bits de dirección: soporta hasta 524288 posiciones
        .DEPTH(307200)     //! 640x480 = 307200 posiciones válidas
    ) vr (
        .wr_clk  (clk),
        .rd_clk  (clk),
        .wr_en   (wr_en),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .rd_en   (video_en),
        .rd_addr (rd_addr),
        .rd_data (rd_data)
    );

    // -------------------------------------------------------------------------
    // Bloque 4: VGAController
    // -------------------------------------------------------------------------

    VGAController vc ( //! Genera sincronización VGA y envía píxeles desde VRAM
        .clk      (clk),
        .rst      (rst),
        .vram_data(rd_data),
        .vram_addr(rd_addr),
        .hsync    (vga_hsync),
        .vsync    (vga_vsync),
        .vga_r    (vga_r),
        .vga_g    (vga_g),
        .vga_b    (vga_b),
        .h_count  (h_count),
        .v_count  (v_count),
        .video_en (video_en),
        .pclk_en  (pclk_en)
    );

endmodule