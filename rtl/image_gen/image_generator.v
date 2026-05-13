//! @title image_generator
//! @author Nicole Irina Corrales Rodríguez
//! @brief Genera el framebuffer visual y escribe los píxeles en la VRAM.
//!
//! Este bloque integra el fondo, los sprites, el renderizador de dígitos y el control
//! de parpadeo. Recorre internamente la pantalla visible y decide el color final de
//! cada píxel según prioridad de capas antes de escribirlo en memoria de video.
module image_generator (
    input  wire        clk, //! Reloj usado para recorrer la pantalla y escribir en VRAM.
    input  wire        rst, //! Reinicio del barrido interno y señales de escritura.
    input  wire [3:0]  hora_dec, //! Decena de la hora que se enviará al renderizador.
    input  wire [3:0]  hora_uni, //! Unidad de la hora que se enviará al renderizador.
    input  wire [3:0]  min_dec, //! Decena de los minutos que se enviará al renderizador.
    input  wire [3:0]  min_uni, //! Unidad de los minutos que se enviará al renderizador.
    input  wire [3:0]  seg_dec, //! Decena de los segundos que se enviará al renderizador.
    input  wire [3:0]  seg_uni, //! Unidad de los segundos que se enviará al renderizador.
    input  wire [1:0]  estado, //! Estado de edición recibido desde el control de hora.
    output reg  [18:0] wr_addr, //! Dirección lineal de escritura hacia la VRAM.
    output reg  [11:0] wr_data, //! Color RGB444 escrito en la VRAM.
    output reg         wr_en, //! Habilitación de escritura del framebuffer.
    input  wire [9:0]  pixel_x, //! Coordenada horizontal del controlador VGA; no gobierna el barrido interno.
    input  wire [8:0]  pixel_y, //! Coordenada vertical del controlador VGA; no gobierna el barrido interno.
    input  wire        video_on //! Indicador de zona visible del controlador VGA; se conserva por interfaz.
);

localparam SCREEN_W = 640; //! Ancho visible del framebuffer VGA.
localparam SCREEN_H = 480; //! Alto visible del framebuffer VGA.

// ============================================================
// Señales internas
// ============================================================
wire        blink; //! Parpadeo general generado por blink_ctrl.
wire [15:0] star_blink; //! Máscara de variación para elementos del fondo.
wire        blink_hours; //! Selección de parpadeo para horas.
wire        blink_mins; //! Selección de parpadeo para minutos.

wire [11:0] bg_color; //! Color de la capa de fondo.

wire        dog_active; //! Indica píxel activo del sprite del perro.
wire [11:0] dog_color; //! Color del sprite del perro.

wire        grill_active; //! Indica píxel activo del sprite de la parrilla.
wire [11:0] grill_color; //! Color del sprite de la parrilla.

wire        fg_active; //! Indica píxel activo de la capa frontal.
wire [11:0] fg_color; //! Color de la capa frontal.

// Contador de píxeles interno
reg [9:0] px; //! Contador horizontal interno usado para llenar la VRAM.
reg [8:0] py; //! Contador vertical interno usado para llenar la VRAM.

// ============================================================
// Instancias de submódulos
// ============================================================
//! @brief Instancia encargada de generar parpadeo para edición y fondo.
blink_ctrl bc (
    .clk        (clk),
    .rst        (rst),
    .estado     (estado),
    .blink      (blink),
    .star_blink (star_blink),
    .blink_hours(blink_hours),
    .blink_mins (blink_mins)
);

//! @brief Instancia que genera la capa de fondo de la escena.
sky_background sb (
    .clk        (clk),
    .rst        (rst),
    .px         (px),
    .py         (py),
    .star_blink (star_blink),
    .bg_color   (bg_color)
);

//! @brief Instancia del sprite de la parrilla.
grill_sprite gs (
    .px          (px),
    .py          (py),
    .grill_active(grill_active),
    .grill_color (grill_color)
);

//! @brief Instancia del sprite del perro.
dog_sprite ds (
    .px        (px),
    .py        (py),
    .dog_active(dog_active),
    .dog_color (dog_color)
);

//! @brief Instancia del renderizador de hora y elementos de primer plano.
digit_renderer dr (
    .px         (px),
    .py         (py),
    .hora_dec   (hora_dec),
    .hora_uni   (hora_uni),
    .min_dec    (min_dec),
    .min_uni    (min_uni),
    .seg_dec    (seg_dec),
    .seg_uni    (seg_uni),
    .blink      (blink),
    .blink_hours(blink_hours),
    .blink_mins (blink_mins),
    .fg_active  (fg_active),
    .fg_color   (fg_color)
);

// ============================================================
// Pipeline de escritura en VRAM
// Prioridad: dígitos/bandeja > perrito > parrilla > fondo
// ============================================================
//! @brief Recorre el framebuffer, calcula la prioridad de capas y escribe en VRAM.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        px      <= 0;
        py      <= 0;
        wr_en   <= 0;
        wr_addr <= 0;
        wr_data <= 0;
    end else begin
        wr_en   <= 1;
        wr_addr <= py * SCREEN_W + px;

        // Prioridad de capas
        if (fg_active)
            wr_data <= fg_color;       // bandeja + dígitos (capa más alta)
        else if (dog_active)
            wr_data <= dog_color;      // perrito + cerveza
        else if (grill_active)
            wr_data <= grill_color;    // parrilla
        else
            wr_data <= bg_color;       // fondo atardecer

        // Avanzar píxel
        if (px == SCREEN_W - 1) begin
            px <= 0;
            py <= (py == SCREEN_H - 1) ? 9'd0 : py + 1;
        end else
            px <= px + 1;
    end
end

endmodule
