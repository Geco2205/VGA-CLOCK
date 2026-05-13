//! @title digit_renderer
//! @author Nicole Irina Corrales Rodríguez
//! @brief Renderiza la hora digital y la bandeja frontal de la imagen VGA.
//!
//! El módulo usa una fuente bitmap de 7x10 escalada para dibujar HH:MM:SS. También
//! genera elementos gráficos de primer plano, como la bandeja y detalles decorativos.
//! fg_active indica que el píxel de salida debe tener prioridad sobre capas inferiores.
module digit_renderer (
    input  wire [9:0]  px, //! Coordenada horizontal del píxel evaluado.
    input  wire [8:0]  py, //! Coordenada vertical del píxel evaluado.
    input  wire [3:0]  hora_dec, //! Decena de la hora mostrada en pantalla.
    input  wire [3:0]  hora_uni, //! Unidad de la hora mostrada en pantalla.
    input  wire [3:0]  min_dec, //! Decena de los minutos mostrados en pantalla.
    input  wire [3:0]  min_uni, //! Unidad de los minutos mostrados en pantalla.
    input  wire [3:0]  seg_dec, //! Decena de los segundos mostrados en pantalla.
    input  wire [3:0]  seg_uni, //! Unidad de los segundos mostrados en pantalla.
    input  wire        blink, //! Señal periódica usada para ocultar o mostrar campos en edición.
    input  wire        blink_hours, //! Habilita parpadeo del campo de horas.
    input  wire        blink_mins, //! Habilita parpadeo del campo de minutos.
    output reg         fg_active, //! Indica que el píxel pertenece a la capa frontal.
    output reg  [11:0] fg_color //! Color RGB444 asignado a la capa frontal.
);

// ============================================================
// Parámetros dígitos
// ============================================================
localparam DIGIT_W  = 7; //! Ancho de la fuente bitmap base.
localparam DIGIT_H  = 10; //! Alto de la fuente bitmap base.
localparam SCALE    = 3; //! Factor de escala aplicado a cada celda de la fuente.
localparam DIGIT_SW = DIGIT_W * SCALE; //! Ancho final de cada dígito escalado.
localparam DIGIT_SH = DIGIT_H * SCALE; //! Alto final de cada dígito escalado.
localparam DIGIT_X0 = 250; //! Coordenada horizontal inicial del reloj.
localparam DIGIT_Y0 = 375; //! Coordenada vertical inicial del reloj.
localparam COLON_W  = 7; //! Separación horizontal reservada para los dos puntos.

localparam X_HD = DIGIT_X0;
localparam X_HU = DIGIT_X0 + DIGIT_SW;
localparam X_C1 = DIGIT_X0 + DIGIT_SW*2;
localparam X_MD = DIGIT_X0 + DIGIT_SW*2 + COLON_W;
localparam X_MU = DIGIT_X0 + DIGIT_SW*3 + COLON_W;
localparam X_C2 = DIGIT_X0 + DIGIT_SW*4 + COLON_W;
localparam X_SD = DIGIT_X0 + DIGIT_SW*4 + COLON_W*2;
localparam X_SU = DIGIT_X0 + DIGIT_SW*5 + COLON_W*2;

// ============================================================
// Bandeja plateada - aritmética explícita de 40 bits
// ============================================================
// FIX: en_elipse_t sin tipo de retorno → Vivado evalúa en 1 bit
// → siempre retorna 1 → bandeja cubre toda la pantalla.
wire [9:0]  b_dx   = (px >= 10'd320) ? (px - 10'd320) : (10'd320 - px);

// bandeja7: cx=320 cy=400 rx=210 ry=52  RHS=119_246_400
wire [9:0]  b7_dy  = (py >= 9'd400) ? (py - 9'd400) : (9'd400 - py);
wire [39:0] b7_lhs = ({30'h0,b_dx}*{30'h0,b_dx}*40'd2704)
                   + ({30'h0,b7_dy}*{30'h0,b7_dy}*40'd44100);
wire bandeja7 = (b7_lhs < 40'd119_246_400);

// bandeja6: cx=320 cy=397 rx=206 ry=48  RHS=97_935_360
wire [9:0]  b6_dy  = (py >= 9'd397) ? (py - 9'd397) : (9'd397 - py);
wire [39:0] b6_lhs = ({30'h0,b_dx}*{30'h0,b_dx}*40'd2304)
                   + ({30'h0,b6_dy}*{30'h0,b6_dy}*40'd42436);
wire bandeja6 = (b6_lhs < 40'd97_935_360);

// bandeja5: cx=320 cy=394 rx=202 ry=44  RHS=78_997_504
wire [9:0]  b5_dy  = (py >= 9'd394) ? (py - 9'd394) : (9'd394 - py);
wire [39:0] b5_lhs = ({30'h0,b_dx}*{30'h0,b_dx}*40'd1936)
                   + ({30'h0,b5_dy}*{30'h0,b5_dy}*40'd40804);
wire bandeja5 = (b5_lhs < 40'd78_997_504);

// bandeja4: cx=320 cy=392 rx=198 ry=40  RHS=62_726_400
wire [9:0]  b4_dy  = (py >= 9'd392) ? (py - 9'd392) : (9'd392 - py);
wire [39:0] b4_lhs = ({30'h0,b_dx}*{30'h0,b_dx}*40'd1600)
                   + ({30'h0,b4_dy}*{30'h0,b4_dy}*40'd39204);
wire bandeja4 = (b4_lhs < 40'd62_726_400);

// bandeja3: cx=320 cy=390 rx=194 ry=37  RHS=51_523_684
wire [9:0]  b3_dy  = (py >= 9'd390) ? (py - 9'd390) : (9'd390 - py);
wire [39:0] b3_lhs = ({30'h0,b_dx}*{30'h0,b_dx}*40'd1369)
                   + ({30'h0,b3_dy}*{30'h0,b3_dy}*40'd37636);
wire bandeja3 = (b3_lhs < 40'd51_523_684);
wire bandeja_borde = bandeja7 && !bandeja6;
wire bandeja_med1  = bandeja6 && !bandeja5;
wire bandeja_med2  = bandeja5 && !bandeja4;
wire bandeja_int   = bandeja4 && !bandeja3;
wire bandeja_core  = bandeja3;

// ============================================================
// Salchichas en bandeja - aritmética explícita de 40 bits
// FIX: en_sal sin tipo de retorno → mismo bug que en_elipse_t
// ============================================================
// s1: cx=208 cy=382 rx=34 ry=10  RHS=34²×10²=115_600
wire [9:0]  s1_dx=(px>=10'd208)?(px-10'd208):(10'd208-px);
wire [9:0]  s1_dy=(py>=9'd382) ?(py-9'd382) :(9'd382-py);
wire [39:0] s1l=({30'h0,s1_dx}*{30'h0,s1_dx}*40'd100)+({30'h0,s1_dy}*{30'h0,s1_dy}*40'd1156);
wire s1=(s1l<40'd115_600);
// s2: cx=320 cy=378 rx=34 ry=10  RHS=115_600
wire [9:0]  s2_dx=(px>=10'd320)?(px-10'd320):(10'd320-px);
wire [9:0]  s2_dy=(py>=9'd378) ?(py-9'd378) :(9'd378-py);
wire [39:0] s2l=({30'h0,s2_dx}*{30'h0,s2_dx}*40'd100)+({30'h0,s2_dy}*{30'h0,s2_dy}*40'd1156);
wire s2=(s2l<40'd115_600);
// s3: cx=432 cy=382 rx=32 ry=10  RHS=32²×10²=102_400
wire [9:0]  s3_dx=(px>=10'd432)?(px-10'd432):(10'd432-px);
wire [9:0]  s3_dy=(py>=9'd382) ?(py-9'd382) :(9'd382-py);
wire [39:0] s3l=({30'h0,s3_dx}*{30'h0,s3_dx}*40'd100)+({30'h0,s3_dy}*{30'h0,s3_dy}*40'd1024);
wire s3=(s3l<40'd102_400);
// s4: cx=260 cy=406 rx=30 ry=9   RHS=30²×9²=72_900
wire [9:0]  s4_dx=(px>=10'd260)?(px-10'd260):(10'd260-px);
wire [9:0]  s4_dy=(py>=9'd406) ?(py-9'd406) :(9'd406-py);
wire [39:0] s4l=({30'h0,s4_dx}*{30'h0,s4_dx}*40'd81)+({30'h0,s4_dy}*{30'h0,s4_dy}*40'd900);
wire s4=(s4l<40'd72_900);
// s5: cx=380 cy=404 rx=30 ry=9   RHS=72_900
wire [9:0]  s5_dx=(px>=10'd380)?(px-10'd380):(10'd380-px);
wire [9:0]  s5_dy=(py>=9'd404) ?(py-9'd404) :(9'd404-py);
wire [39:0] s5l=({30'h0,s5_dx}*{30'h0,s5_dx}*40'd81)+({30'h0,s5_dy}*{30'h0,s5_dy}*40'd900);
wire s5=(s5l<40'd72_900);

// Salsas ketchup
wire k1 = (py == 9'd378) && (px >= 10'd192 && px <= 10'd224);
wire k2 = (py == 9'd374) && (px >= 10'd304 && px <= 10'd336);
wire k3 = (py == 9'd378) && (px >= 10'd416 && px <= 10'd448);
// Salsas mostaza
wire m1 = (py == 9'd386) && (px >= 10'd194 && px <= 10'd222);
wire m2 = (py == 9'd382) && (px >= 10'd306 && px <= 10'd334);
wire m3 = (py == 9'd402) && (px >= 10'd249 && px <= 10'd271);
wire m4 = (py == 9'd400) && (px >= 10'd369 && px <= 10'd391);

// ============================================================
// Fuente bitmap 7x10 para dígitos
// ============================================================
//! @brief Devuelve la fila de la fuente bitmap asociada a un dígito decimal.
function [6:0] font_row;
    input [3:0] digit;
    input [3:0] row;
    begin
        case (digit)
            4'd0: case(row)
                4'd0: font_row=7'b0111110; 4'd1: font_row=7'b1100011;
                4'd2: font_row=7'b1100011; 4'd3: font_row=7'b1100011;
                4'd4: font_row=7'b1100011; 4'd5: font_row=7'b1100011;
                4'd6: font_row=7'b1100011; 4'd7: font_row=7'b1100011;
                4'd8: font_row=7'b1100011; 4'd9: font_row=7'b0111110;
                default: font_row=7'b0000000;
            endcase
            4'd1: case(row)
                4'd0: font_row=7'b0011000; 4'd1: font_row=7'b0111000;
                4'd2: font_row=7'b0011000; 4'd3: font_row=7'b0011000;
                4'd4: font_row=7'b0011000; 4'd5: font_row=7'b0011000;
                4'd6: font_row=7'b0011000; 4'd7: font_row=7'b0011000;
                4'd8: font_row=7'b0011000; 4'd9: font_row=7'b1111111;
                default: font_row=7'b0000000;
            endcase
            4'd2: case(row)
                4'd0: font_row=7'b0111110; 4'd1: font_row=7'b1100011;
                4'd2: font_row=7'b0000011; 4'd3: font_row=7'b0000011;
                4'd4: font_row=7'b0000110; 4'd5: font_row=7'b0001100;
                4'd6: font_row=7'b0011000; 4'd7: font_row=7'b0110000;
                4'd8: font_row=7'b1100000; 4'd9: font_row=7'b1111111;
                default: font_row=7'b0000000;
            endcase
            4'd3: case(row)
                4'd0: font_row=7'b0111110; 4'd1: font_row=7'b1100011;
                4'd2: font_row=7'b0000011; 4'd3: font_row=7'b0000011;
                4'd4: font_row=7'b0011110; 4'd5: font_row=7'b0000011;
                4'd6: font_row=7'b0000011; 4'd7: font_row=7'b0000011;
                4'd8: font_row=7'b1100011; 4'd9: font_row=7'b0111110;
                default: font_row=7'b0000000;
            endcase
            4'd4: case(row)
                4'd0: font_row=7'b0000110; 4'd1: font_row=7'b0001110;
                4'd2: font_row=7'b0011110; 4'd3: font_row=7'b0110110;
                4'd4: font_row=7'b1100110; 4'd5: font_row=7'b1111111;
                4'd6: font_row=7'b0000110; 4'd7: font_row=7'b0000110;
                4'd8: font_row=7'b0000110; 4'd9: font_row=7'b0000110;
                default: font_row=7'b0000000;
            endcase
            4'd5: case(row)
                4'd0: font_row=7'b1111111; 4'd1: font_row=7'b1100000;
                4'd2: font_row=7'b1100000; 4'd3: font_row=7'b1100000;
                4'd4: font_row=7'b1111110; 4'd5: font_row=7'b0000011;
                4'd6: font_row=7'b0000011; 4'd7: font_row=7'b0000011;
                4'd8: font_row=7'b1100011; 4'd9: font_row=7'b0111110;
                default: font_row=7'b0000000;
            endcase
            4'd6: case(row)
                4'd0: font_row=7'b0111110; 4'd1: font_row=7'b1100011;
                4'd2: font_row=7'b1100000; 4'd3: font_row=7'b1100000;
                4'd4: font_row=7'b1111110; 4'd5: font_row=7'b1100011;
                4'd6: font_row=7'b1100011; 4'd7: font_row=7'b1100011;
                4'd8: font_row=7'b1100011; 4'd9: font_row=7'b0111110;
                default: font_row=7'b0000000;
            endcase
            4'd7: case(row)
                4'd0: font_row=7'b1111111; 4'd1: font_row=7'b0000011;
                4'd2: font_row=7'b0000011; 4'd3: font_row=7'b0000110;
                4'd4: font_row=7'b0001100; 4'd5: font_row=7'b0011000;
                4'd6: font_row=7'b0011000; 4'd7: font_row=7'b0011000;
                4'd8: font_row=7'b0011000; 4'd9: font_row=7'b0011000;
                default: font_row=7'b0000000;
            endcase
            4'd8: case(row)
                4'd0: font_row=7'b0111110; 4'd1: font_row=7'b1100011;
                4'd2: font_row=7'b1100011; 4'd3: font_row=7'b1100011;
                4'd4: font_row=7'b0111110; 4'd5: font_row=7'b1100011;
                4'd6: font_row=7'b1100011; 4'd7: font_row=7'b1100011;
                4'd8: font_row=7'b1100011; 4'd9: font_row=7'b0111110;
                default: font_row=7'b0000000;
            endcase
            4'd9: case(row)
                4'd0: font_row=7'b0111110; 4'd1: font_row=7'b1100011;
                4'd2: font_row=7'b1100011; 4'd3: font_row=7'b1100011;
                4'd4: font_row=7'b0111111; 4'd5: font_row=7'b0000011;
                4'd6: font_row=7'b0000011; 4'd7: font_row=7'b0000011;
                4'd8: font_row=7'b1100011; 4'd9: font_row=7'b0111110;
                default: font_row=7'b0000000;
            endcase
            default: font_row=7'b0000000;
        endcase
    end
endfunction

// ============================================================
// Función para detectar píxel de dígito
// ============================================================
//! @brief Determina si la coordenada actual pertenece a un dígito escalado.
function pixel_in_digit;
    input [9:0] ppx, x_start;
    input [8:0] ppy;
    input [3:0] digit;
    input       blink_en;
    input       blink_sig;
    reg [9:0]   lx;
    reg [8:0]   ly;
    reg [3:0]   fc, fr;
    reg [6:0]   rb;
    begin
        if (blink_en && !blink_sig)
            pixel_in_digit = 0;
        else if (ppx >= x_start && ppx < x_start + DIGIT_SW &&
                 ppy >= DIGIT_Y0 && ppy < DIGIT_Y0 + DIGIT_SH) begin
            lx = ppx - x_start;
            ly = ppy - DIGIT_Y0;
            fc = lx / SCALE;
            fr = ly / SCALE;
            rb = font_row(digit, fr);
            pixel_in_digit = rb[DIGIT_W - 1 - fc];
        end else
            pixel_in_digit = 0;
    end
endfunction

// Dos puntos
//! @brief Determina si la coordenada actual pertenece a los dos puntos del reloj.
function pixel_in_colon;
    input [9:0] ppx, x_start;
    input [8:0] ppy;
    input       blink_sig;
    begin
        if (!blink_sig)
            pixel_in_colon = 0;
        else if (ppx >= x_start && ppx < x_start + COLON_W &&
                 ((ppy >= DIGIT_Y0 + DIGIT_SH/4 &&
                   ppy <  DIGIT_Y0 + DIGIT_SH/4 + SCALE*2) ||
                  (ppy >= DIGIT_Y0 + (DIGIT_SH*3)/4 &&
                   ppy <  DIGIT_Y0 + (DIGIT_SH*3)/4 + SCALE*2)))
            pixel_in_colon = 1;
        else
            pixel_in_colon = 0;
    end
endfunction

// ============================================================
// Color final con prioridad
// ============================================================
//! @brief Selecciona la capa frontal y su color final para la coordenada evaluada.
always @(*) begin
    fg_active = 1'b1;

    // ── Dígitos ──────────────────────────────────────────────
    // Horas y minutos: negro normal, ROJO KETCHUP al parpadear
    // Segundos y dos puntos: siempre negro
    if (pixel_in_digit(px, X_HD, py, hora_dec, blink_hours, blink) ||
        pixel_in_digit(px, X_HU, py, hora_uni, blink_hours, blink))
        fg_color = blink_hours ? 12'hF00 : 12'h000;  // ketchup al editar horas

    else if (pixel_in_digit(px, X_MD, py, min_dec, blink_mins, blink) ||
             pixel_in_digit(px, X_MU, py, min_uni, blink_mins, blink))
        fg_color = blink_mins ? 12'hF00 : 12'h000;   // ketchup al editar minutos

    else if (pixel_in_digit(px, X_SD, py, seg_dec, 1'b0, 1'b0) ||
             pixel_in_digit(px, X_SU, py, seg_uni, 1'b0, 1'b0) ||
             pixel_in_colon(px, X_C1, py, blink)                ||
             pixel_in_colon(px, X_C2, py, blink))
        fg_color = 12'h000;   // negro siempre

    // Ketchup
    else if (k1 || k2 || k3)
        fg_color = 12'hC00;
    // Mostaza
    else if (m1 || m2 || m3 || m4)
        fg_color = 12'hFB0;
    // Salchichas oscuro (cuerpo)
    else if (s1 || s2 || s3 || s4 || s5)
        fg_color = 12'hC32; // carne rojo-café
    // Bandeja capas plateadas
    else if (bandeja_borde)
        fg_color = 12'h888;
    else if (bandeja_med1)
        fg_color = 12'hAAA;
    else if (bandeja_med2)
        fg_color = 12'hCCC;
    else if (bandeja_int)
        fg_color = 12'hDDD;
    else if (bandeja_core)
        fg_color = 12'hEEE;
    else begin
        fg_active = 1'b0;
        fg_color  = 12'h000;
    end
end

endmodule
