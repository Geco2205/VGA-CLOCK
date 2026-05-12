// ============================================================
// Módulo: sky_background
// Propósito:
//   Genera el fondo de la escena VGA: cielo por bandas, sol,
//   nubes, pájaros y colinas. El color se entrega en RGB444.
//
// Criterio de diseño:
//   La paleta del cielo se calcula con comparaciones fijas por
//   banda vertical para reducir lógica aritmética y evitar artefactos
//   por ancho de datos durante síntesis.
// ============================================================
module sky_background (
    input  wire        clk,
    input  wire        rst,
    input  wire [9:0]  px,
    input  wire [8:0]  py,
    input  wire [15:0] star_blink,
    output reg  [11:0] bg_color
);

// ============================================================
// Sol
// ============================================================
// Se dibuja con tres radios para obtener centro, corona media y
// halo exterior.
wire [9:0]  sol_dx   = (px >= 10'd320) ? (px - 10'd320) : (10'd320 - px);
wire [9:0]  sol_dy   = (py >= 9'd210)  ? (py - 9'd210)  : (9'd210  - py);
wire [19:0] sol_d2   = sol_dx*sol_dx + sol_dy*sol_dy;
wire sol_core        = sol_d2 < 20'd900;    // r=30
wire sol_mid         = sol_d2 < 20'd2500;   // r=50
wire sol_outer       = sol_d2 < 20'd5625;   // r=75

// ============================================================
// Colinas del horizonte
// ============================================================
wire [9:0] cil_h  = (px < 10'd90) ? (10'd90 - px) : (px - 10'd90);
wire colina_izq   = (px <= 10'd265) && (py > 9'd340) &&
                    (py > (9'd370 - cil_h[9:2]));

wire [9:0] cdr_h  = (px < 10'd555) ? (10'd555 - px) : (px - 10'd555);
wire colina_der   = (px >= 10'd375) && (py > 9'd340) &&
                    (py > (9'd368 - cdr_h[9:2]));

wire [9:0] cen_h  = (px > 10'd320) ? (px - 10'd320) : (10'd320 - px);
wire colina_cen   = (px > 10'd200) && (px < 10'd440) &&
                    (py > 9'd350) &&
                    (py > (9'd390 - cen_h[9:1]));

// ============================================================
// Nubes
// ============================================================
// Cada nube se arma con rectángulos escalonados para conservar
// formas simples y sintetizables.
wire nube1 = ((px >= 10'd50  && px <= 10'd200) && (py >= 9'd42 && py <= 9'd54)) ||
             ((px >= 10'd70  && px <= 10'd180) && (py >= 9'd32 && py <= 9'd42)) ||
             ((px >= 10'd92  && px <= 10'd158) && (py >= 9'd23 && py <= 9'd32));

wire nube2 = ((px >= 10'd310 && px <= 10'd510) && (py >= 9'd45 && py <= 9'd57)) ||
             ((px >= 10'd332 && px <= 10'd488) && (py >= 9'd34 && py <= 9'd45)) ||
             ((px >= 10'd358 && px <= 10'd462) && (py >= 9'd24 && py <= 9'd34));

wire nube3 = ((px >= 10'd520 && px <= 10'd628) && (py >= 9'd72 && py <= 9'd82)) ||
             ((px >= 10'd536 && px <= 10'd612) && (py >= 9'd63 && py <= 9'd72)) ||
             ((px >= 10'd552 && px <= 10'd596) && (py >= 9'd56 && py <= 9'd63));

// ============================================================
// Pájaros
// ============================================================
// Figuras pequeñas en forma de V, definidas punto a punto.
wire pajaro1 = ((px==10'd78)&&(py==9'd112))||((px==10'd79)&&(py==9'd111))||
               ((px==10'd80)&&(py==9'd110))||((px==10'd81)&&(py==9'd110))||
               ((px==10'd82)&&(py==9'd111))||((px==10'd83)&&(py==9'd112));

wire pajaro2 = ((px==10'd104)&&(py==9'd93))||((px==10'd105)&&(py==9'd92))||
               ((px==10'd106)&&(py==9'd91))||((px==10'd107)&&(py==9'd91))||
               ((px==10'd108)&&(py==9'd92))||((px==10'd109)&&(py==9'd93));

wire pajaro3 = ((px==10'd554)&&(py==9'd102))||((px==10'd555)&&(py==9'd101))||
               ((px==10'd556)&&(py==9'd100))||((px==10'd557)&&(py==9'd100))||
               ((px==10'd558)&&(py==9'd101))||((px==10'd559)&&(py==9'd102));

// ============================================================
// Paleta del cielo por bandas verticales
// ============================================================
// py 0-35    : azul profundo
// py 36-70   : azul medio
// py 71-100  : azul claro
// py 101-130 : azul-lavanda
// py 131-160 : lavanda-rosado
// py 161-190 : rosado-salmón
// py 191-220 : naranja-rosa
// py 221-260 : naranja
// py 261-300 : naranja-amarillo
// py 301-340 : amarillo suave
// py 341+    : verde suelo
// ============================================================

// ============================================================
// Selección final de color del fondo
// ============================================================
// Prioridad: nubes > sol > pájaros > colinas > bandas de cielo.
always @(*) begin
    if (nube1 || nube2 || nube3)
        bg_color = 12'hFFF;
    else if (sol_core)
        bg_color = 12'hFFE;
    else if (sol_mid)
        bg_color = 12'hFD4;
    else if (sol_outer)
        bg_color = 12'hF92;
    else if (pajaro1 || pajaro2 || pajaro3)
        bg_color = 12'h113;
    else if (colina_izq || colina_der)
        bg_color = 12'h141;
    else if (colina_cen)
        bg_color = 12'h252;
    // Bandas del cielo implementadas solo con comparaciones.
    else if (py < 9'd36)
        bg_color = 12'h12B;   // azul profundo
    else if (py < 9'd71)
        bg_color = 12'h25B;   // azul medio
    else if (py < 9'd101)
        bg_color = 12'h48C;   // azul claro
    else if (py < 9'd131)
        bg_color = 12'h7AB;   // azul-lavanda
    else if (py < 9'd161)
        bg_color = 12'hA89;   // lavanda-rosado
    else if (py < 9'd191)
        bg_color = 12'hD76;   // rosado-salmón
    else if (py < 9'd221)
        bg_color = 12'hF84;   // naranja-rosa
    else if (py < 9'd261)
        bg_color = 12'hFA5;   // naranja
    else if (py < 9'd301)
        bg_color = 12'hFC7;   // naranja-amarillo
    else if (py < 9'd341)
        bg_color = 12'hFD9;   // amarillo suave horizonte
    else
        bg_color = 12'h252;   // verde suelo
end

endmodule