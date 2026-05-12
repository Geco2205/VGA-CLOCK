// ============================================================
// Módulo: grill_sprite
// Propósito:
//   Genera el sprite de la parrilla usando comparaciones de píxel
//   y regiones geométricas. No utiliza memoria de imagen externa.
//
// Posición aproximada:
//   centro x = 196, y = 295
//
// Salida:
//   grill_active indica si el píxel pertenece al sprite.
//   grill_color entrega el color RGB444 de la región activa.
// ============================================================
module grill_sprite (
    input  wire [9:0]  px,
    input  wire [8:0]  py,
    output reg         grill_active,
    output reg  [11:0] grill_color
);

// ============================================================
// Función auxiliar para distancia al cuadrado
// ============================================================
function [19:0] dist2;
    input [9:0] x1, x2;
    input [8:0] y1, y2;
    reg [9:0] dx, dy;
    begin
        dx = (x1 > x2) ? (x1 - x2) : (x2 - x1);
        dy = (y1 > y2) ? (y1 - y2) : (y2 - y1);
        dist2 = dx*dx + dy*dy;
    end
endfunction

// Las elipses se dejan expandidas en señales de 40 bits para
// controlar el ancho de los productos durante síntesis.

// ============================================================
// Componentes principales de la parrilla
// ============================================================
// Tazón de la parrilla, modelado con elipses concéntricas.
wire [9:0]  g_dx   = (px>=10'd196)?(px-10'd196):(10'd196-px);
wire [9:0]  g_dy   = (py>=9'd295) ?(py-9'd295) :(9'd295-py);
// rx=62,ry=20 → RHS=62²×20²=1_537_600
wire [39:0] g62l   = ({30'h0,g_dx}*{30'h0,g_dx}*40'd400)+({30'h0,g_dy}*{30'h0,g_dy}*40'd3844);
wire        g_e62  = (g62l < 40'd1_537_600);
// rx=58,ry=17 → RHS=58²×17²=972_196
wire [39:0] g58l   = ({30'h0,g_dx}*{30'h0,g_dx}*40'd289)+({30'h0,g_dy}*{30'h0,g_dy}*40'd3364);
wire        g_e58  = (g58l < 40'd972_196);
// rx=60,ry=18 → RHS=60²×18²=1_166_400
wire [39:0] g60l   = ({30'h0,g_dx}*{30'h0,g_dx}*40'd324)+({30'h0,g_dy}*{30'h0,g_dy}*40'd3600);
wire        g_e60  = (g60l < 40'd1_166_400);

wire borde_tazon   = g_e62 && !g_e58;
wire interior      = g_e58;
wire bowl_inferior = (py > 9'd295) && (py <= 9'd340) && g_e62;
wire rejilla_h1    = (py == 9'd282) && g_e60;
wire rejilla_h2    = (py == 9'd290) && g_e60;
wire rejilla_h3    = (py == 9'd300) && g_e60;

wire rejilla_v1 = (px == 10'd154) && (py >= 9'd278 && py <= 9'd306);
wire rejilla_v2 = (px == 10'd170) && (py >= 9'd275 && py <= 9'd309);
wire rejilla_v3 = (px == 10'd186) && (py >= 9'd274 && py <= 9'd310);
wire rejilla_v4 = (px == 10'd202) && (py >= 9'd274 && py <= 9'd310);
wire rejilla_v5 = (px == 10'd218) && (py >= 9'd275 && py <= 9'd309);
wire rejilla_v6 = (px == 10'd234) && (py >= 9'd278 && py <= 9'd306);

wire fuego1 = (px >= 10'd168 && px <= 10'd180) &&
              (py >= 9'd268 && py <= 9'd295) &&
              (py >= (9'd295 - (px - 10'd168) * 9'd2));
wire fuego2 = (px >= 10'd172 && px <= 10'd186) &&
              (py >= 9'd258 && py <= 9'd295) &&
              (py >= (9'd295 - (px - 10'd172) * 9'd3));
wire fuego3 = (px >= 10'd175 && px <= 10'd183) &&
              (py >= 9'd272 && py <= 9'd295);
wire fuego4 = (px >= 10'd188 && px <= 10'd200) &&
              (py >= 9'd265 && py <= 9'd295) &&
              (py >= (9'd295 - (px - 10'd188) * 9'd2));
wire fuego5 = (px >= 10'd192 && px <= 10'd206) &&
              (py >= 9'd258 && py <= 9'd295) &&
              (py >= (9'd295 - (px - 10'd192) * 9'd3));
wire fuego6 = (px >= 10'd208 && px <= 10'd220) &&
              (py >= 9'd268 && py <= 9'd295) &&
              (py >= (9'd295 - (px - 10'd208) * 9'd2));
wire fuego7 = (px >= 10'd215 && px <= 10'd227) &&
              (py >= 9'd272 && py <= 9'd295);

// Salchichas rx=20,ry=7 → RHS=20²×7²=19_600
wire [9:0]  sal1_dx=(px>=10'd180)?(px-10'd180):(10'd180-px);
wire [9:0]  sal1_dy=(py>=9'd283) ?(py-9'd283) :(9'd283-py);
wire [39:0] sal1l=({30'h0,sal1_dx}*{30'h0,sal1_dx}*40'd49)+({30'h0,sal1_dy}*{30'h0,sal1_dy}*40'd400);
wire sal1_body  = (sal1l < 40'd19_600);
wire sal1_mark1 = (py == 9'd279) && (px >= 10'd171 && px <= 10'd180);
wire sal1_mark2 = (py == 9'd275) && (px >= 10'd173 && px <= 10'd182);

wire [9:0]  sal2_dx=(px>=10'd210)?(px-10'd210):(10'd210-px);
wire [9:0]  sal2_dy=(py>=9'd282) ?(py-9'd282) :(9'd282-py);
wire [39:0] sal2l=({30'h0,sal2_dx}*{30'h0,sal2_dx}*40'd49)+({30'h0,sal2_dy}*{30'h0,sal2_dy}*40'd400);
wire sal2_body  = (sal2l < 40'd19_600);
wire sal2_mark1 = (py == 9'd278) && (px >= 10'd201 && px <= 10'd211);
wire sal2_mark2 = (py == 9'd274) && (px >= 10'd202 && px <= 10'd212);

wire [9:0]  sal3_dx=(px>=10'd196)?(px-10'd196):(10'd196-px);
wire [9:0]  sal3_dy=(py>=9'd294) ?(py-9'd294) :(9'd294-py);
wire [39:0] sal3l=({30'h0,sal3_dx}*{30'h0,sal3_dx}*40'd49)+({30'h0,sal3_dy}*{30'h0,sal3_dy}*40'd400);
wire sal3_body  = (sal3l < 40'd19_600);
wire sal3_mark1 = (py == 9'd290) && (px >= 10'd187 && px <= 10'd197);
wire sal3_mark2 = (py == 9'd286) && (px >= 10'd188 && px <= 10'd198);

wire pata_izq_g = (px >= 10'd156 && px <= 10'd163) &&
                  (py >= 9'd310 && py <= 9'd363) &&
                  (px + py >= 10'd473);

// Patas inclinadas. Las comparaciones se expresan sin constantes
// negativas para evitar errores de ancho o underflow.
wire pata_der_g = (px >= 10'd229 && px <= 10'd236) &&
                  (py >= 9'd310 && py <= 9'd363) &&
                  (py >= 9'd80) && (px <= py - 9'd80);

wire barra_g = (py >= 9'd348 && py <= 9'd353) &&
               (px >= 10'd150 && px <= 10'd244);

wire rueda_g = dist2(px, 10'd246, py, 9'd355) < 20'd64;
wire rueda_c = dist2(px, 10'd246, py, 9'd355) < 20'd16;

wire humo1 = (px == 10'd178) && (py >= 9'd215 && py <= 9'd270) &&
             ((py - 9'd215) % 4 < 2);
wire humo2 = (px == 10'd196) && (py >= 9'd212 && py <= 9'd267) &&
             ((py - 9'd212) % 4 < 2);
wire humo3 = (px == 10'd214) && (py >= 9'd215 && py <= 9'd270) &&
             ((py - 9'd215) % 4 < 2);

// ============================================================
// Selección de color por prioridad visual
// ============================================================
always @(*) begin
    grill_active = 1'b1;

    if (humo1 || humo2 || humo3)
        grill_color = 12'hCCC;
    else if (sal1_mark1 || sal1_mark2 ||
             sal2_mark1 || sal2_mark2 ||
             sal3_mark1 || sal3_mark2)
        grill_color = 12'h310; // marca parrilla oscura
    else if (sal1_body || sal2_body || sal3_body)
        grill_color = 12'hC32; // carne asada rojo-café
    else if (rejilla_h1 || rejilla_h2 || rejilla_h3 ||
             rejilla_v1 || rejilla_v2 || rejilla_v3 ||
             rejilla_v4 || rejilla_v5 || rejilla_v6)
        grill_color = 12'h666;
    else if (fuego3 || fuego7)
        grill_color = 12'hFA0;
    else if (fuego2 || fuego5)
        grill_color = 12'hF60;
    else if (fuego1 || fuego4 || fuego6)
        grill_color = 12'hF40;
    else if (interior)
        grill_color = 12'h111;
    else if (borde_tazon)
        grill_color = 12'hEE2;
    else if (bowl_inferior)
        grill_color = 12'hAA0;
    else if (rueda_c)
        grill_color = 12'h666;
    else if (rueda_g)
        grill_color = 12'h444;
    else if (pata_izq_g || pata_der_g || barra_g)
        grill_color = 12'h555;
    else begin
        grill_active = 1'b0;
        grill_color  = 12'h000;
    end
end

endmodule