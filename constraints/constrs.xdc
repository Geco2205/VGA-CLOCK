## ============================================================
## Constraints: Nexys A7-100T
## Proyecto:    Controlador VGA con Reloj Digital
## Autor:       Keillin Loaisiga
## Descripción: Asignación de pines y estándares de E/S para
##              la tarjeta Nexys A7. Incluye reloj, reset,
##              botones, switches y salidas VGA.
## ============================================================

## ------------------------------------------------------------
## Reloj del sistema: 100 MHz - Pin E3
## ------------------------------------------------------------
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## ------------------------------------------------------------
## Reset - BTNC (botón central): activo alto
## ------------------------------------------------------------
set_property PACKAGE_PIN N17 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

## ------------------------------------------------------------
## BTNU - Avanzar estado (SET_HOURS → SET_MIN → RUN)
## ------------------------------------------------------------
set_property PACKAGE_PIN M18 [get_ports btn_c]
set_property IOSTANDARD LVCMOS33 [get_ports btn_c]

## ------------------------------------------------------------
## BTNR - Retroceder estado (RUN → SET_MIN → SET_HOURS)
## ------------------------------------------------------------
set_property PACKAGE_PIN P17 [get_ports btn_r]
set_property IOSTANDARD LVCMOS33 [get_ports btn_r]

## ------------------------------------------------------------
## Switches SW[8:0]
## SW[7:4] = decenas, SW[3:0] = unidades, SW[8] = habilita ajuste
## ------------------------------------------------------------
set_property PACKAGE_PIN J15 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
set_property PACKAGE_PIN L16 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
set_property PACKAGE_PIN M13 [get_ports {sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]
set_property PACKAGE_PIN R15 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]
set_property PACKAGE_PIN R17 [get_ports {sw[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[4]}]
set_property PACKAGE_PIN T18 [get_ports {sw[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[5]}]
set_property PACKAGE_PIN U18 [get_ports {sw[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[6]}]
set_property PACKAGE_PIN R13 [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[7]}]
set_property PACKAGE_PIN T8  [get_ports {sw[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[8]}]

## ------------------------------------------------------------
## VGA - Sincronización
## ------------------------------------------------------------
set_property PACKAGE_PIN B11 [get_ports vga_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hsync]
set_property PACKAGE_PIN B12 [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vsync]

## ------------------------------------------------------------
## VGA - Canal Rojo (4 bits)
## ------------------------------------------------------------
set_property PACKAGE_PIN A3 [get_ports {vga_r[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN B4 [get_ports {vga_r[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN C5 [get_ports {vga_r[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN A4 [get_ports {vga_r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[3]}]

## ------------------------------------------------------------
## VGA - Canal Verde (4 bits)
## ------------------------------------------------------------
set_property PACKAGE_PIN C6 [get_ports {vga_g[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN A5 [get_ports {vga_g[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN B6 [get_ports {vga_g[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN A6 [get_ports {vga_g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[3]}]

## ------------------------------------------------------------
## VGA - Canal Azul (4 bits)
## ------------------------------------------------------------
set_property PACKAGE_PIN B7 [get_ports {vga_b[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN C7 [get_ports {vga_b[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN D7 [get_ports {vga_b[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN D8 [get_ports {vga_b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[3]}]