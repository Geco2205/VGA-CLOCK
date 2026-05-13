//! @title blink_ctrl
//! @author Nicole Irina Corrales Rodríguez
//! @brief Genera las señales de parpadeo usadas por la interfaz gráfica del reloj.
//!
//! El bloque produce un parpadeo periódico y una máscara de estrellas variable.
//! También separa el modo de edición de horas y minutos para que otros módulos
//! decidan qué parte de la imagen debe parpadear.
module blink_ctrl (
    input  wire        clk, //! Reloj del sistema usado para contar el periodo de parpadeo.
    input  wire        rst, //! Reinicio síncrono/asíncrono según la sensibilidad del bloque secuencial.
    input  wire [1:0]  estado, //! Modo de operación del reloj; selecciona si se editan horas o minutos.
    output reg         blink, //! Señal periódica de parpadeo general.
    output reg  [15:0] star_blink, //! Máscara pseudoaleatoria usada para variar estrellas visibles.
    output wire        blink_hours, //! Indica que el campo de horas está en modo de edición.
    output wire        blink_mins //! Indica que el campo de minutos está en modo de edición.
);

localparam SET_HOURS = 2'd0; //! Estado local asociado a la edición de horas.
localparam SET_MIN   = 2'd1; //! Estado local asociado a la edición de minutos.

reg [24:0] blink_cnt; //! Contador usado para definir el periodo de parpadeo.

//! @brief Actualiza el contador de parpadeo y la máscara pseudoaleatoria de estrellas.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        blink_cnt  <= 0;
        blink      <= 0;
        star_blink <= 16'hA5C3;
    end else begin
        if (blink_cnt == 25'd49_999_999) begin
            blink_cnt  <= 0;
            blink      <= ~blink;
            // LFSR para cambiar estrellas visibles
            star_blink <= {star_blink[14:0],
                           star_blink[15] ^ star_blink[13]};
        end else
            blink_cnt <= blink_cnt + 1;
    end
end

// Solo indican en qué modo de edición estamos (sin mezclar con blink).
// digit_renderer combina estas señales con `blink` para hacer el parpadeo.
//! @brief Decodificación del estado de edición para el renderizador de dígitos.
assign blink_hours = (estado == SET_HOURS);
assign blink_mins  = (estado == SET_MIN);

endmodule
