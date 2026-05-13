//! @title dog_sprite
//! @author Nicole Irina Corrales Rodríguez
//! @brief Dibuja el sprite del perro y sus elementos decorativos dentro de la escena.
//!
//! El sprite se forma mediante regiones geométricas definidas por px y py. Incluye
//! cuerpo, cabeza, delantal, gorro, pinzas y una lata decorativa. dog_active se
//! activa únicamente cuando la coordenada pertenece a algún elemento visible.
module dog_sprite (
    input  wire [9:0]  px, //! Coordenada horizontal del píxel evaluado.
    input  wire [8:0]  py, //! Coordenada vertical del píxel evaluado.
    output reg         dog_active, //! Indica que el píxel pertenece al sprite del perro.
    output reg  [11:0] dog_color //! Color RGB444 asignado al píxel activo del sprite.
);

// ============================================================
// Colores del perrito
// ============================================================
localparam COL_CAFE_OSC  = 12'h852; // cuerpo oscuro
localparam COL_CAFE_MED  = 12'hA63; // cuerpo medio
localparam COL_CAFE_CLA  = 12'hC85; // panza
localparam COL_CAFE_HOC  = 12'hDA9; // hocico claro beige
localparam COL_NEGRO     = 12'h111; // nariz/ojos
localparam COL_BLANCO    = 12'hFFF; // ojos brillo/delantal
localparam COL_ROJO_DEL  = 12'hCC2; // texto BBQ (rojo)
localparam COL_GRIS_DEL  = 12'hF0F; // (no usado - ver abajo)
localparam COL_LENGUA    = 12'hE05; // lengua
localparam COL_CAFE_OSEJ = 12'h741; // orejas
localparam COL_PINZA     = 12'h888; // pinzas metal
localparam COL_GORRO     = 12'hFFF; // gorro blanco

// ============================================================
// Funciones helper - distancia²
// ============================================================
//! @brief Calcula distancia cuadrática para regiones circulares del sprite.
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

// ============================================================
// Zonas del perrito (coordenadas absolutas en pantalla)
// ============================================================

// --- PATAS TRASERAS ---
wire pata_izq = (px >= 10'd418 && px <= 10'd434) &&
                (py >= 9'd318 && py <= 9'd360);
wire pata_der = (px >= 10'd458 && px <= 10'd474) &&
                (py >= 9'd320 && py <= 9'd360);
wire pata_izq_pie = (px >= 10'd414 && px <= 10'd438) &&
                    (py >= 9'd355 && py <= 9'd363);
wire pata_der_pie = (px >= 10'd454 && px <= 10'd478) &&
                    (py >= 9'd355 && py <= 9'd363);

// --- CUERPO ---
// Cuerpo - elipse en lugar de círculo para silueta más delgada
// Centro (454, 287). Antes: círculo r≈66px (132px ancho).
// Ahora: bx=50 horizontal, by=78 vertical → 100px ancho (24% más delgado).
wire [9:0]  dog_dx  = (px >= 10'd454) ? (px - 10'd454) : (10'd454 - px);
wire [9:0]  dog_dy  = (py >= 9'd287)  ? (py - 9'd287)  : (9'd287  - py);

// cuerpo_ext: bx=50, by=78  RHS=50²×78²=15_210_000
wire [39:0] ce_lhs  = ({30'h0,dog_dx}*{30'h0,dog_dx}*40'd6084)
                    + ({30'h0,dog_dy}*{30'h0,dog_dy}*40'd2500);
wire cuerpo_ext = (ce_lhs < 40'd15_210_000);

// cuerpo_med: bx=44, by=70  RHS=44²×70²=9_486_400
wire [39:0] cm_lhs  = ({30'h0,dog_dx}*{30'h0,dog_dx}*40'd4900)
                    + ({30'h0,dog_dy}*{30'h0,dog_dy}*40'd1936);
wire cuerpo_med = (cm_lhs < 40'd9_486_400);

// panza: bx=26, by=38  RHS=26²×38²=976_144
wire [9:0]  pz_dx   = (px >= 10'd454) ? (px - 10'd454) : (10'd454 - px);
wire [9:0]  pz_dy   = (py >= 9'd294)  ? (py - 9'd294)  : (9'd294  - py);
wire [39:0] pz_lhs  = ({30'h0,pz_dx}*{30'h0,pz_dx}*40'd1444)
                    + ({30'h0,pz_dy}*{30'h0,pz_dy}*40'd676);
wire panza = (pz_lhs < 40'd976_144);

// --- COLA ---
wire cola = (px >= 10'd400 && px <= 10'd418) &&
            (py >= 9'd200 && py <= 9'd270) &&
            (px + py >= 10'd610) && (px + py <= 10'd670);

// --- DELANTAL BLANCO ---
wire delantal = (px >= 10'd430 && px <= 10'd478) &&
                (py >= 9'd247 && py <= 9'd329);
wire delantal_tira_izq = (px >= 10'd436 && px <= 10'd445) &&
                          (py >= 9'd213 && py <= 9'd248);
wire delantal_tira_der = (px >= 10'd463 && px <= 10'd472) &&
                          (py >= 9'd213 && py <= 9'd248);
wire delantal_linea1 = (py == 9'd270) &&
                        (px >= 10'd431 && px <= 10'd477);
wire delantal_linea2 = (py == 9'd294) &&
                        (px >= 10'd431 && px <= 10'd477);
wire delantal_linea3 = (py == 9'd318) &&
                        (px >= 10'd431 && px <= 10'd477);
wire bolsillo = (px >= 10'd434 && px <= 10'd454) &&
                (py >= 9'd300 && py <= 9'd318);

// --- BRAZO IZQUIERDO (hacia abajo con cerveza) ---
wire brazo_izq = (px >= 10'd402 && px <= 10'd432) &&
                 (py >= 9'd258 && py <= 9'd322) &&
                 (px + py >= 10'd668) && (px + py <= 10'd745);

// --- BRAZO DERECHO (hacia arriba con pinzas) ---
wire brazo_der = (px >= 10'd476 && px <= 10'd530) &&
                 (py >= 9'd155 && py <= 9'd252) &&
                 ((px - 10'd476) + (9'd252 - py) < 10'd80);

// --- PINZAS + MANGO DEL PINCHO -----------------------------------------
wire pinza_izq_pal = (px >= 10'd510 && px <= 10'd516) &&
                     (py >= 9'd118 && py <= 9'd158);
wire pinza_der_pal = (px >= 10'd522 && px <= 10'd528) &&
                     (py >= 9'd118 && py <= 9'd158);
wire pinza_izq_cab = (dist2(px, 10'd513, py, 9'd118) < 20'd64);
wire pinza_der_cab = (dist2(px, 10'd525, py, 9'd118) < 20'd64);
wire pinza_union   = (px >= 10'd514 && px <= 10'd524) &&
                     (py >= 9'd148 && py <= 9'd158);
// Mango largo que conecta pinzas (y=158) con el brazo derecho (y≈225)
wire pinza_mango   = (px >= 10'd516 && px <= 10'd522) &&
                     (py >= 9'd155 && py <= 9'd228);

// --- OREJAS (detrás de la cabeza) ---
wire oreja_izq = (px >= 10'd406 && px <= 10'd430) &&
                 (py >= 9'd198 && py <= 9'd260) &&
                 (px + py <= 10'd660);
wire oreja_der = (px >= 10'd478 && px <= 10'd502) &&
                 (py >= 9'd195 && py <= 9'd252) &&
                 (px - py >= 10'd228);

// --- CABEZA ---
wire cabeza = dist2(px, 10'd454, py, 9'd204) < 20'd2500;
wire cabeza_top = dist2(px, 10'd454, py, 9'd190) < 20'd1600;

// --- HOCICO ---
wire hocico_ext = dist2(px, 10'd476, py, 9'd214) < 20'd900;
wire hocico_int = dist2(px, 10'd479, py, 9'd217) < 20'd576;
wire nariz = dist2(px, 10'd494, py, 9'd208) < 20'd64;
wire boca1 = (px >= 10'd480 && px <= 10'd488) && (py == 9'd220);
wire boca2 = (px >= 10'd488 && px <= 10'd496) && (py == 9'd222);
wire lengua = dist2(px, 10'd489, py, 9'd230) < 20'd100;

// --- OJO ---
wire ojo_ext = dist2(px, 10'd446, py, 9'd200) < 20'd121;
wire ojo_int = dist2(px, 10'd446, py, 9'd200) < 20'd64;
wire ojo_bri = dist2(px, 10'd448, py, 9'd196) < 20'd16;
wire ceja    = (py == 9'd191) && (px >= 10'd438 && px <= 10'd455);

// --- GORRO DE CHEF - más alto y subido, con líneas verticales --------
// Ala (brim) ancha - descansa sobre la frente
wire gorro_base  = (px >= 10'd422 && px <= 10'd486) &&
                   (py >= 9'd156 && py <= 9'd168);
// Cuerpo alto rectangular (68px de alto, forma de chef clásico)
wire gorro_top   = (px >= 10'd434 && px <= 10'd474) &&
                   (py >= 9'd88  && py <= 9'd156);
// Línea divisoria ala/cuerpo
wire gorro_linea = (py == 9'd156) &&
                   (px >= 10'd423 && px <= 10'd485);
// Líneas verticales decorativas grises dentro del cuerpo
wire gorro_v_lines = gorro_top &&
                     (px == 10'd441 || px == 10'd449 || px == 10'd457 ||
                      px == 10'd465 || px == 10'd473);

// ============================================================
// BOTELLA HEINEKEN
// Centro x≈397, posición y=258-338
// ============================================================
// Tapón dorado
wire lata_tapa      = (px >= 10'd393 && px <= 10'd401) && (py >= 9'd258 && py <= 9'd265);
// Cuello verde oscuro (estrecho)
wire lata_top_part  = (px >= 10'd391 && px <= 10'd403) && (py >= 9'd265 && py <= 9'd285);
// Hombro (transición cuello-cuerpo)
wire lata_hombro    = (px >= 10'd385 && px <= 10'd409) && (py >= 9'd285 && py <= 9'd293);
// Cuerpo principal verde
wire lata_body      = (px >= 10'd383 && px <= 10'd411) && (py >= 9'd293 && py <= 9'd336);
// Etiqueta roja Heineken (franja central)
wire lata_roja      = (px >= 10'd383 && px <= 10'd411) && (py >= 9'd300 && py <= 9'd322);
// Estrella Heineken (5 píxeles en cruz + diagonales)
wire aguila_cuerpo  = (px == 10'd397) && (py >= 9'd306 && py <= 9'd316);
wire aguila_cabeza  = (py == 9'd311) && (px >= 10'd392 && px <= 10'd402);
wire aguila_ala_izq = (px == 10'd393) && (py >= 9'd308 && py <= 9'd314);
wire aguila_ala_der = (px == 10'd401) && (py >= 9'd308 && py <= 9'd314);
wire aguila_cola1   = (px == 10'd395) && (py >= 9'd307 && py <= 9'd315);
wire aguila_cola2   = (px == 10'd399) && (py >= 9'd307 && py <= 9'd315);
wire aguila_cola3   = (px == 10'd397) && (py == 9'd311); // centro
// Base botella
wire corona         = (px >= 10'd385 && px <= 10'd409) && (py >= 9'd334 && py <= 9'd338);
wire corona_punta1  = 1'b0;
wire corona_punta2  = 1'b0;
wire corona_punta3  = 1'b0;
// Espuma (burbujas sobre el tapón)
wire lata_espuma1 = dist2(px, 10'd397, py, 9'd255) < 20'd49;
wire lata_espuma2 = dist2(px, 10'd391, py, 9'd253) < 20'd25;
wire lata_espuma3 = dist2(px, 10'd403, py, 9'd253) < 20'd25;

// ============================================================
// Prioridad de capas y color final
// ============================================================
//! @brief Selecciona la parte visible del perro y entrega el color correspondiente.
always @(*) begin
    dog_active = 1'b1;
    // Capas en orden de prioridad (primero = encima)

    // ── Botella Heineken ──────────────────────────────────────────────
    // Espuma
    if (lata_espuma1 || lata_espuma2 || lata_espuma3)
        dog_color = 12'hFFF;
    // Tapón dorado
    else if (lata_tapa)
        dog_color = 12'hFD0;
    // Estrella blanca sobre etiqueta roja
    else if (aguila_cuerpo || aguila_cabeza ||
             aguila_ala_izq || aguila_ala_der ||
             aguila_cola1 || aguila_cola2 || aguila_cola3)
        dog_color = 12'hFFF;
    // Etiqueta roja
    else if (lata_roja)
        dog_color = 12'hC00;
    // Cuello verde claro (vidrio)
    else if (lata_top_part)
        dog_color = 12'h282;
    // Hombro
    else if (lata_hombro)
        dog_color = 12'h373;
    // Cuerpo verde oscuro
    else if (lata_body)
        dog_color = 12'h1A1;
    // Base / aro inferior
    else if (corona)
        dog_color = 12'h141;
    // Mango del pincho
    else if (pinza_mango)
        dog_color = 12'hAAA;
    // Pinzas
    else if (pinza_izq_cab || pinza_der_cab)
        dog_color = 12'h666;
    else if (pinza_union)
        dog_color = 12'hAAA;
    else if (pinza_izq_pal || pinza_der_pal)
        dog_color = 12'h999;
    // Gorro chef
    else if (gorro_v_lines)
        dog_color = 12'hBBB; // líneas verticales grises
    else if (gorro_base || gorro_top)
        dog_color = COL_GORRO;
    else if (gorro_linea)
        dog_color = 12'hCCC;
    // Nariz
    else if (nariz)
        dog_color = COL_NEGRO;
    // Boca
    else if (boca1 || boca2)
        dog_color = 12'hF99;
    // Lengua
    else if (lengua)
        dog_color = COL_LENGUA;
    // Hocico interior
    else if (hocico_int)
        dog_color = COL_CAFE_HOC;
    // Hocico exterior
    else if (hocico_ext)
        dog_color = 12'hCA8; // hocico beige
    // Ojo brillo
    else if (ojo_bri)
        dog_color = COL_BLANCO;
    // Ojo interior
    else if (ojo_int)
        dog_color = 12'h285;
    // Ojo exterior
    else if (ojo_ext)
        dog_color = COL_NEGRO;
    // Ceja
    else if (ceja)
        dog_color = 12'h531;
    // Cabeza
    else if (cabeza)
        dog_color = 12'hA63;
    else if (cabeza_top)
        dog_color = 12'h963;
    // Orejas (detrás cabeza)
    else if (oreja_izq || oreja_der)
        dog_color = COL_CAFE_OSEJ;
    // Delantal líneas
    else if (delantal_linea1 || delantal_linea2 || delantal_linea3)
        dog_color = 12'hDDD;
    // Bolsillo
    else if (bolsillo)
        dog_color = 12'hDDF; // bolsillo mantel
    // Tirantes delantal
    else if (delantal_tira_izq || delantal_tira_der)
        dog_color = 12'hDDD;
    // Delantal
    else if (delantal)
        dog_color = 12'hEEF; // blanco mantel
    // Panza
    else if (panza)
        dog_color = COL_CAFE_CLA;
    // Cuerpo medio
    else if (cuerpo_med)
        dog_color = COL_CAFE_MED;
    // Cuerpo exterior
    else if (cuerpo_ext)
        dog_color = COL_CAFE_OSC;
    // Cola
    else if (cola)
        dog_color = COL_CAFE_MED;
    // Brazo derecho (pinzas)
    else if (brazo_der)
        dog_color = COL_CAFE_MED;
    // Brazo izquierdo (cerveza)
    else if (brazo_izq)
        dog_color = COL_CAFE_MED;
    // Patas
    else if (pata_izq || pata_der)
        dog_color = COL_CAFE_OSC;
    else if (pata_izq_pie || pata_der_pie)
        dog_color = 12'h531;
    else begin
        dog_active = 1'b0;
        dog_color  = 12'h000;
    end
end

endmodule
