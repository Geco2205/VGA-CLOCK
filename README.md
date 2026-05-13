# Controlador VGA con Reloj Digital

**EL3313 — Taller de Diseño Digital | I Semestre 2026**  
**Plataforma:** Nexys A7 (Artix-7) | **Resolución:** 640×480 @ 60 Hz | **Reloj:** 100 MHz

---


## Integrantes

- Nicole Irina Corrales Rodríguez
- Gerson Adrián Cordero Zúñiga
- Keilin Tatiana Loásiga Téllez

## Repositorio

**Repositorio público del proyecto:**  
[https://github.com/Geco2205/VGA-CLOCK](https://github.com/Geco2205/VGA-CLOCK)

---

## Diagrama de Bloques del Sistema

```mermaid
flowchart TD

    subgraph INPUTS [" Entradas — Nexys A7 "]
        direction TB
        clk100["CLK — 100 MHz"]
        rst["BTNC — Reset general"]
        btn_c["BTNU — Avanzar estado<br/>SET_HOURS → SET_MIN → RUN"]
        btn_r["BTNR — Retroceder estado<br/>RUN → SET_MIN → SET_HOURS"]
        sw["Switches SW[8:0]<br/>SW[8] = Activar modo ajuste<br/>SW[7:4] = Valor decenas<br/>SW[3:0] = Valor unidades"]
    end

    subgraph HC [" Bloque 1 — hour_control.v "]
        direction TB

        subgraph SYNC_BLOCK [" Sincronización de botones "]
            sync_btnc["sincronizador.v<br/>2 flip-flops en serie<br/>Evita metaestabilidad en BTNU"]
            sync_btnr["sincronizador.v<br/>2 flip-flops en serie<br/>Evita metaestabilidad en BTNR"]
        end

        subgraph DB_BLOCK [" Filtro de rebote "]
            db_btnc["debounce.v<br/>Espera 20 ms estable<br/>Genera 1 pulso limpio por presión"]
            db_btnr["debounce.v<br/>Espera 20 ms estable<br/>Genera 1 pulso limpio por presión"]
        end

        subgraph SC_BLOCK [" Generador de 1 segundo "]
            seg_cnt["seg_counter.v<br/>Cuenta 100 000 000 ciclos<br/>Sale un pulso cada 1 segundo"]
        end

        subgraph FSM_BLOCK [" Máquina de estados + Contador de hora "]
            direction LR
            fsm["3 modos de operación<br/>SET_HOURS — ajustar horas<br/>SET_MIN — ajustar minutos<br/>RUN — reloj corriendo"]
            counter_logic["Contador BCD encadenado<br/>hh : mm : ss<br/>Rango 00:00:00 hasta 23:59:59<br/>Reinicia al llegar al límite"]
        end
    end

    subgraph IG [" Bloque 2 — image_generator.v "]
        direction TB

        subgraph BLINK [" Control de parpadeo "]
            blink_ctrl["blink_ctrl.v<br/>Toggle cada 500 ms<br/>Parpadea horas en SET_HOURS<br/>Parpadea minutos en SET_MIN"]
        end

        subgraph BG [" Capa 4 — Fondo de pantalla "]
            sky_bg["sky_background.v<br/>Gradiente de atardecer<br/>Sol con 3 capas de color<br/>Colinas y pájaros"]
        end

        subgraph GS [" Capa 3 — Parrilla "]
            grill_sp["grill_sprite.v<br/>Tazón circular rojo<br/>Fuego y rejilla<br/>Salchichas y humo"]
        end

        subgraph DS [" Capa 2 — Perrito chef "]
            dog_sp["dog_sprite.v<br/>Dachshund de pie<br/>Gorro y delantal BBQ<br/>Pinzas y cerveza Imperial"]
        end

        subgraph DR [" Capa 1 — Bandeja y hora "]
            dig_r["digit_renderer.v<br/>Bandeja plateada ovalada<br/>Salchichas con ketchup y mostaza<br/>Dígitos bitmap 7x10 escalados x5"]
        end

        priority["Regla de prioridad de capas<br/>1 Bandeja y hora — siempre encima<br/>2 Perrito<br/>3 Parrilla<br/>4 Fondo — siempre abajo"]
    end

    subgraph VRAM_BLOCK [" Bloque 3 — vram.v "]
        direction LR
        wr_port["Puerto de escritura<br/>Recibe pixeles del generador<br/>Velocidad 100 MHz"]
        bram["BRAM Dual-Port<br/>640 x 480 = 307 200 pixeles<br/>12 bits por pixel RGB444<br/>R[3:0] G[3:0] B[3:0]"]
        rd_port["Puerto de lectura<br/>Entrega pixeles al VGA<br/>Velocidad 100 MHz"]
    end

    subgraph VGA_BLOCK [" Bloque 4 — VGAController.v "]
        direction TB

        subgraph SYNC_VGA [" SyncVGA.v — Generador de sincronía "]
            h_cnt["Contador horizontal<br/>0 a 799 por linea<br/>640 pixeles visibles<br/>160 de blanking"]
            v_cnt["Contador vertical<br/>0 a 524 por frame<br/>480 lineas visibles<br/>45 de blanking"]
            sync_gen["Señales de sincronía<br/>HSYNC — fin de linea<br/>VSYNC — fin de frame<br/>video_en — zona visible<br/>pclk_en — pulso a 25 MHz"]
        end

        subgraph ADDR_GEN [" Cálculo de dirección VRAM "]
            addr_calc["Dirección de lectura<br/>addr = fila x 640 + columna<br/>Implementado con desplazamientos<br/>sin multiplicador hardware"]
        end

        subgraph PIX_OUT [" Salida de color al monitor "]
            pix_logic["Alinea latencia de 1 ciclo de BRAM<br/>Fuerza negro fuera de zona visible<br/>Separa RGB en 3 canales de 4 bits"]
        end
    end

    subgraph OUTPUTS [" Salidas al monitor "]
        direction TB
        hsync_out["HSYNC — Sincronía horizontal"]
        vsync_out["VSYNC — Sincronía vertical"]
        rgb_out["Color del pixel<br/>Rojo [3:0] Verde [3:0] Azul [3:0]"]
        monitor["Monitor VGA<br/>640x480 a 60 Hz"]
    end

    clk100 --> HC
    clk100 --> IG
    clk100 --> VRAM_BLOCK
    clk100 --> VGA_BLOCK
    rst --> HC
    rst --> IG
    rst --> VGA_BLOCK
    btn_c --> sync_btnc
    btn_r --> sync_btnr
    sw --> fsm

    sync_btnc --> db_btnc
    sync_btnr --> db_btnr
    db_btnc -- "Un pulso limpio<br/>por presión de BTNU" --> fsm
    db_btnr -- "Un pulso limpio<br/>por presión de BTNR" --> fsm
    seg_cnt -- "Un pulso<br/>cada 1 segundo" --> counter_logic
    fsm <--> counter_logic

    counter_logic -- "Hora actual en BCD<br/>Decenas y unidades de<br/>horas minutos y segundos" --> IG
    fsm -- "Modo activo<br/>para controlar parpadeo" --> blink_ctrl
    fsm -- "Modo activo<br/>para parpadeo de dígitos" --> dig_r

    blink_ctrl -- "Parpadeo cada 500ms<br/>Parpadear horas o minutos<br/>segun el modo activo" --> sky_bg
    blink_ctrl -- "Parpadeo cada 500ms<br/>Parpadear horas o minutos<br/>segun el modo activo" --> dig_r

    sky_bg   -- "Color del fondo<br/>para este pixel" --> priority
    grill_sp -- "Este pixel es parrilla<br/>y su color" --> priority
    dog_sp   -- "Este pixel es perrito<br/>y su color" --> priority
    dig_r    -- "Este pixel es bandeja u hora<br/>y su color" --> priority

    priority -- "Habilitar escritura<br/>Dirección del pixel<br/>Color final del pixel" --> wr_port
    wr_port --> bram

    h_cnt --> addr_calc
    v_cnt --> addr_calc
    h_cnt --> sync_gen
    v_cnt --> sync_gen
    sync_gen -- "Zona visible activa" --> pix_logic
    sync_gen -- "Señales HSYNC y VSYNC" --> pix_logic

    addr_calc -- "Dirección del<br/>pixel a leer" --> rd_port
    rd_port --> bram
    bram -- "Color del pixel<br/>almacenado en BRAM" --> pix_logic

    pix_logic --> hsync_out
    pix_logic --> vsync_out
    pix_logic --> rgb_out
    hsync_out --> monitor
    vsync_out --> monitor
    rgb_out   --> monitor

    sync_gen -- "Posición actual del pixel<br/>Columna 0 a 639<br/>Fila 0 a 479<br/>Zona visible activa" --> IG
```

---

## Descripción de Módulos

### Bloque 1 — `hour_control.v`

Mantiene y gestiona la hora actual del reloj digital.

| Sub-módulo | Función |
|---|---|
| `sincronizador.v` (×2) | Doble flip-flop para evitar metaestabilidad en `btn_c` y `btn_r` |
| `debounce.v` (×2) | Filtra rebotes mecánicos — 20 ms @ 100 MHz |
| `seg_counter.v` | Genera un pulso de 1 Hz contando 100 000 000 ciclos |
| FSM interna | 3 estados: `SET_HOURS`, `SET_MIN`, `RUN` |
| Contador BCD | Cuenta `hh:mm:ss` de 00:00:00 a 23:59:59 con carry encadenado |

**Interfaz de usuario:**

- `SW[8]` → activa modo ajuste
- `SW[7:4]` → decenas del campo seleccionado
- `SW[3:0]` → unidades del campo seleccionado
- `BTNU` → avanza estado
- `BTNR` → retrocede estado

---

### Bloque 2 — `image_generator.v`

Genera el contenido visual píxel a píxel y lo escribe en la VRAM. Este bloque compone cuatro capas visuales principales y selecciona el color final del píxel según prioridad.

| Sub-módulo | Capa | Contenido |
|---|---|---|
| `digit_renderer.v` | 1 — mayor prioridad | Bandeja plateada, salchichas y hora BCD en bitmap |
| `dog_sprite.v` | 2 | Dachshund de pie con gorro, delantal BBQ, pinzas y cerveza Imperial |
| `grill_sprite.v` | 3 | Parrilla circular con fuego, rejilla y salchichas |
| `sky_background.v` | 4 — menor prioridad | Gradiente de atardecer con sol, colinas y pájaros |
| `blink_ctrl.v` | — | Señales de parpadeo para modo ajuste y efectos visuales |

**Regla de composición:**

```text
pixel final = bandeja u hora activa  →  color de bandeja u hora
            = perrito activo         →  color del perrito
            = parrilla activa        →  color de la parrilla
            = ninguno                →  color del fondo
```

El módulo genera las señales de escritura hacia la memoria de video:

| Señal | Función |
|---|---|
| `wr_en` | Habilita la escritura de un píxel en VRAM |
| `wr_addr` | Dirección lineal del píxel dentro del framebuffer |
| `wr_data` | Color final del píxel en formato RGB444 |

La dirección de escritura se calcula a partir de la posición del píxel:

```text
wr_addr = y × 640 + x
```

---

### Bloque 3 — `vram.v`

Memoria de video de doble puerto implementada como framebuffer del sistema VGA.

| Parámetro | Valor |
|---|---|
| Resolución | 640 × 480 = 307 200 posiciones |
| Ancho de dato | 12 bits — formato RGB444 |
| Ancho de dirección | 19 bits |
| Puerto escritura | 100 MHz — desde `image_generator.v` |
| Puerto lectura | 100 MHz — desde `VGAController.v` |

La VRAM permite separar la generación de imagen del proceso de visualización VGA.  
El generador de imagen escribe el contenido visual en memoria, mientras que el controlador VGA lee los datos siguiendo el barrido de pantalla.

---

### Bloque 4 — `VGAController.v`

Genera las señales VGA estándar 640×480 @ 60 Hz y lee la VRAM para obtener el color de cada píxel.

| Sub-módulo | Función |
|---|---|
| `SyncVGA.v` | Contadores horizontal y vertical; genera `HSYNC`, `VSYNC`, `video_en` y `pclk_en` |
| Generador de dirección | Calcula `addr = fila × 640 + columna` usando desplazamientos |
| Lógica de salida RGB | Alinea latencia de BRAM y fuerza negro fuera de zona visible |

**Temporización VGA 640×480 @ 60 Hz:**

```text
Horizontal: 640 visible | 16 FP | 96 sync | 48 BP  = 800 total
Vertical:   480 visible | 10 FP |  2 sync | 33 BP  = 525 total
Pixel clock: 100 MHz dividido entre 4 = 25 MHz
```

---

## Jerarquía de Módulos

```text
top.v
├── hour_control.v              ← Bloque 1
│   ├── sincronizador.v  (×2)
│   ├── debounce.v       (×2)
│   └── seg_counter.v
├── image_generator.v           ← Bloque 2
│   ├── blink_ctrl.v
│   ├── sky_background.v
│   ├── grill_sprite.v
│   ├── dog_sprite.v
│   └── digit_renderer.v
├── vram.v                      ← Bloque 3
└── VGAController.v             ← Bloque 4
    └── SyncVGA.v
```

---

## Evidencia de uso de inteligencia artificial

Durante el desarrollo del proyecto se utilizó inteligencia artificial como herramienta de apoyo para comprender conceptos, analizar alternativas de implementación, revisar módulos Verilog, generar explicaciones técnicas y documentar el funcionamiento de la generación de imagen y la VRAM.

La inteligencia artificial se utilizó como apoyo durante el proceso de diseño, documentación y validación conceptual. La integración, pruebas y verificación del funcionamiento en FPGA fueron realizadas dentro del desarrollo del proyecto.

### Conversaciones compartidas utilizadas

- [Conversación en Claude — apoyo técnico 1](https://claude.ai/share/df3a9d99-df0a-4e0a-9dfb-02739b5cf39e)
- [Conversación en Claude — apoyo técnico 2](https://claude.ai/share/a87040c6-7a55-4622-a60e-3578bf6a88ee)

### Capturas de prompts utilizados

Las siguientes capturas muestran evidencia del uso de IA durante el proceso de consulta, análisis y documentación del proyecto.

<details>
<summary>Ver capturas de prompts de IA</summary>

#### Captura 1
![Prompt IA 1](doc/imgs_ia_p1/1.png)

#### Captura 2
![Prompt IA 2](doc/imgs_ia_p1/2.png)

#### Captura 3
![Prompt IA 3](doc/imgs_ia_p1/3.png)

#### Captura 4
![Prompt IA 4](doc/imgs_ia_p1/4.png)

#### Captura 5
![Prompt IA 5](doc/imgs_ia_p1/5.png)

#### Captura 6
![Prompt IA 6](doc/imgs_ia_p1/6.png)

#### Captura 7
![Prompt IA 7](doc/imgs_ia_p1/7.png)

#### Captura 8
![Prompt IA 8](doc/imgs_ia_p1/8.png)

#### Captura 9
![Prompt IA 9](doc/imgs_ia_p1/9.png)

#### Captura 10
![Prompt IA 10](doc/imgs_ia_p1/10.png)

#### Captura 11
![Prompt IA 11](doc/imgs_ia_p1/11.png)

#### Captura 12
![Prompt IA 12](doc/imgs_ia_p1/12.png)

#### Captura 13
![Prompt IA 13](doc/imgs_ia_p1/13.png)

#### Captura 14
![Prompt IA 14](doc/imgs_ia_p1/14.png)

#### Captura 15
![Prompt IA 15](doc/imgs_ia_p1/15.png)

#### Captura 16
![Prompt IA 16](doc/imgs_ia_p1/16.png)

#### Captura 17
![Prompt IA 17](doc/imgs_ia_p1/17.png)

#### Captura 18
![Prompt IA 18](doc/imgs_ia_p1/18.png)

#### Captura 19
![Prompt IA 19](doc/imgs_ia_p1/19.png)

#### Captura 20
![Prompt IA 20](doc/imgs_ia_p1/20.png)

#### Captura 21
![Prompt IA 21](doc/imgs_ia_p1/21.png)

#### Captura 22
![Prompt IA 22](doc/imgs_ia_p1/22.png)

#### Captura 23
![Prompt IA 23](doc/imgs_ia_p1/23.png)

#### Captura 24
![Prompt IA 24](doc/imgs_ia_p1/24.png)

#### Captura 25
![Prompt IA 25](doc/imgs_ia_p1/25.png)

#### Captura 26
![Prompt IA 26](doc/imgs_ia_p1/26.png)

#### Captura 27
![Prompt IA 27](doc/imgs_ia_p1/27.png)

#### Captura 28
![Prompt IA 28](doc/imgs_ia_p1/28.png)

#### Captura 29
![Prompt IA 29](doc/imgs_ia_p1/29.png)

#### Captura 30
![Prompt IA 30](doc/imgs_ia_p1/30.png)

#### Captura 31
![Prompt IA 31](doc/imgs_ia_p1/31.png)

#### Captura 32
![Prompt IA 32](doc/imgs_ia_p1/32.png)

#### Captura 33
![Prompt IA 33](doc/imgs_ia_p1/33.png)

#### Captura 34
![Prompt IA 34](doc/imgs_ia_p1/34.png)

#### Captura 35
![Prompt IA 35](doc/imgs_ia_p1/35.png)

</details>

---

## Consideraciones de diseño

- El sistema se diseñó de forma modular, separando control de hora, generación visual, memoria de video y controlador VGA.
- La VRAM funciona como framebuffer, permitiendo desacoplar la escritura de imagen de la lectura VGA.
- La generación visual se realiza mediante capas con prioridad, lo que facilita integrar fondo, sprites y hora digital.
- Los datos de color se manejan en formato RGB444, compatible con las salidas VGA de 4 bits por canal.
- La documentación en código fue elaborada con comentarios técnicos siguiendo un estilo compatible con documentación HDL.

---

## Proyecto

**Curso:** EL3313 — Taller de Diseño Digital  
**Periodo:** I Semestre 2026  
**Plataforma:** Nexys A7  
**Lenguaje:** Verilog HDL  

---
