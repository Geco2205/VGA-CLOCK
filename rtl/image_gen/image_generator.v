// ============================================================
// Módulo: image_generator
// Propósito:
//   Genera el framebuffer completo de la escena VGA y lo escribe
//   en la VRAM. Para formar cada píxel combina fondo, parrilla,
//   perro y capa frontal del reloj.
//
// Nota de interfaz:
//   pixel_x, pixel_y y video_on se conservan para mantener la
//   conexión con el módulo top y el controlador VGA. La escritura
//   de VRAM usa el barrido interno px/py definido en este módulo.
// ============================================================
module image_generator (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  hora_dec,
    input  wire [3:0]  hora_uni,
    input  wire [3:0]  min_dec,
    input  wire [3:0]  min_uni,
    input  wire [3:0]  seg_dec,
    input  wire [3:0]  seg_uni,
    input  wire [1:0]  estado,
    output reg  [18:0] wr_addr,
    output reg  [11:0] wr_data,
    output reg         wr_en,
    input  wire [9:0]  pixel_x,
    input  wire [8:0]  pixel_y,
    input  wire        video_on
);

localparam SCREEN_W = 640;
localparam SCREEN_H = 480;

// ============================================================
// Señales internas de composición y escritura
// ============================================================
wire        blink;
wire [15:0] star_blink;
wire        blink_hours;
wire        blink_mins;

wire [11:0] bg_color;

wire        dog_active;
wire [11:0] dog_color;

wire        grill_active;
wire [11:0] grill_color;

wire        fg_active;
wire [11:0] fg_color;

// Barrido interno usado para recorrer las 640x480 posiciones.
reg [9:0] px;
reg [8:0] py;

// ============================================================
// Submódulos gráficos usados para formar la escena
// ============================================================
blink_ctrl bc (
    .clk        (clk),
    .rst        (rst),
    .estado     (estado),
    .blink      (blink),
    .star_blink (star_blink),
    .blink_hours(blink_hours),
    .blink_mins (blink_mins)
);

sky_background sb (
    .clk        (clk),
    .rst        (rst),
    .px         (px),
    .py         (py),
    .star_blink (star_blink),
    .bg_color   (bg_color)
);

grill_sprite gs (
    .px          (px),
    .py          (py),
    .grill_active(grill_active),
    .grill_color (grill_color)
);

dog_sprite ds (
    .px        (px),
    .py        (py),
    .dog_active(dog_active),
    .dog_color (dog_color)
);

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
// Escritura secuencial del framebuffer en VRAM
// ============================================================
// Orden de prioridad visual:
//   capa frontal del reloj > perro > parrilla > fondo.
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

        // Selección del color final según la capa activa.
        if (fg_active)
            wr_data <= fg_color;       // bandeja + dígitos (capa más alta)
        else if (dog_active)
            wr_data <= dog_color;      // perrito + cerveza
        else if (grill_active)
            wr_data <= grill_color;    // parrilla
        else
            wr_data <= bg_color;       // fondo atardecer

        // Avance del barrido interno de escritura.
        if (px == SCREEN_W - 1) begin
            px <= 0;
            py <= (py == SCREEN_H - 1) ? 9'd0 : py + 1;
        end else
            px <= px + 1;
    end
end

endmodule