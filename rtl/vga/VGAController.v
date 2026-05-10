`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Module      : VGAController
// Project     : Controlador VGA con Reloj Digital
// Description : Controlador VGA completo. Se divide internamente en:
//                 1) SyncVGA    - generadores de sincronización (H/V counters,
//                                 HSYNC, VSYNC, video_en)
//                 2) Lógica de dirección VRAM - calcula la dirección de lectura
//                                 de la VRAM a partir de (h_count, v_count)
//                 3) Lógica de salida RGB - en zona visible toma el dato de
//                                 VRAM; fuera de ella fuerza negro.
//
// El módulo expone h_count, v_count y pclk_en para que el Image Generator
// pueda sincronizarse con el barrido del controlador VGA.
//
// VRAM:
//   - Resolución: 640 x 480 pixeles = 307 200 posiciones
//   - Ancho de dato: 12 bits de color {R[3:0], G[3:0], B[3:0]}
//   - Ancho de dirección: 19 bits (2^19 = 524 288 > 307 200)
//   - Dirección: addr = v_count * 640 + h_count
//     Implementado sin multiplicador: 640 = 2^9 + 2^7
//     addr = (v_count << 9) + (v_count << 7) + h_count
//
// Latencia de BRAM:
//   La BRAM en modo de lectura síncrona tiene 1 ciclo de latencia.
//   La señal video_en se registra (video_en_d) para alinear el enmascaramiento
//   RGB con el dato que ya salió de la BRAM.
//
// Inputs  : clk        - Reloj de sistema (100 MHz)
//           rst        - Reset síncrono activo alto
//           vram_data  - Dato de color leído de la VRAM {R,G,B} 4 bits c/u
// Outputs : vram_addr  - Dirección de lectura de la VRAM (19 bits)
//           hsync      - Señal HSYNC hacia conector VGA
//           vsync      - Señal VSYNC hacia conector VGA
//           vga_r      - Canal rojo   (4 bits, hacia Nexys A7 JA/VGA)
//           vga_g      - Canal verde  (4 bits)
//           vga_b      - Canal azul   (4 bits)
//           h_count    - Posición horizontal actual (uso del Image Generator)
//           v_count    - Posición vertical actual   (uso del Image Generator)
//           video_en   - Zona visible (uso del Image Generator)
//           pclk_en    - Pixel clock enable (uso del Image Generator)
//
//------------------------------------------------------------------------------

module VGAController (
    input  wire        clk,      
    input  wire        rst,        

  
    input  wire [11:0] vram_data,  
    output wire [18:0] vram_addr,   

  
    output wire        hsync,
    output wire        vsync,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,

   
    output wire [9:0]  h_count,     // Coordenada X del pixel actual
    output wire [9:0]  v_count,     // Coordenada Y del pixel actual
    output wire        video_en,    // 1 = zona visible
    output wire        pclk_en      // Pixel clock enable
);

    //--------------------------------------------------------------------------
    // Sub-módulo 1: Generador de sincronización

    wire        sync_video_en;
    wire        pclk;
    wire [9:0]  h_cnt, v_cnt;

    SyncVGA u_sync (
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

    //--------------------------------------------------------------------------
    // Sub-módulo 2: Lógica de dirección VRAM
    //
    // addr = v_count * 640 + h_count
    // 640 = 2^9 + 2^7  →  sin multiplicador DSP:
    // addr = (v_count << 9) + (v_count << 7) + h_count
    //
    // La dirección se presenta de forma combinacional para que la BRAM la
    // registre en el siguiente flanco de subida (latencia 1 ciclo).
    //--------------------------------------------------------------------------
    wire [18:0] addr_calc;

    assign addr_calc = ({9'd0, v_cnt} << 9)   // v * 512
                     + ({9'd0, v_cnt} << 7)   // v * 128  → v * 640
                     + {9'd0, h_cnt};          // + h

    assign vram_addr = addr_calc;

    //--------------------------------------------------------------------------
    // Sub-módulo 3: Lógica de salida RGB
    //
    // La BRAM tiene 1 ciclo de latencia: el dato en vram_data corresponde
    // a la dirección presentada en el ciclo anterior.
    // Se registra video_en con el mismo retardo para que el enmascaramiento
    // quede alineado con el dato de la BRAM.
    //--------------------------------------------------------------------------
    reg video_en_d; // video_en retardado 1 ciclo (alineado con dato BRAM)

    always @(posedge clk) begin
        if (rst)
            video_en_d <= 1'b0;
        else if (pclk)
            video_en_d <= sync_video_en;
    end

    always @(posedge clk) begin
        if (rst) begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end else if (pclk) begin
            if (video_en_d) begin
   
                vga_r <= vram_data[11:8];
                vga_g <= vram_data[7:4];
                vga_b <= vram_data[3:0];
            end else begin
   
                vga_r <= 4'h0;
                vga_g <= 4'h0;
                vga_b <= 4'h0;
            end
        end
    end

endmodule