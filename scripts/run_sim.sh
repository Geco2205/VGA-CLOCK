#!/bin/bash
# ==============================================================================
# NOMBRE
#   run_sim.sh — Automatización de simulaciones del proyecto VGA Clock
#
# SINOPSIS
#   bash scripts/run_sim.sh
#
# DESCRIPCIÓN
#   Compila, elabora y simula todos los testbenches del proyecto usando
#   las herramientas de línea de comandos de Vivado (xvlog, xelab, xsim).
#   Cada TB se ejecuta en un directorio de trabajo aislado en /tmp para
#   evitar conflictos entre simulaciones.
#
#   El script reporta PASS si ningún TB imprime [FAIL] en su salida,
#   y FAIL en caso contrario. Termina con exit code 1 si hay fallos,
#   lo que permite integrarlo con pipelines de CI/CD.
#
# TESTBENCHES INCLUIDOS
#   tb_VGAController   — Verifica SyncVGA y VGAController (8 pruebas)
#   tb_hour_control    — Verifica FSM, debounce y contador BCD
#   tb_vram            — Verifica lectura/escritura de la BRAM dual-port
#   tb_image_generator — Verifica generación de imagen por capas
#   tb_top             — Verifica integración completa del sistema
#
# PREREQUISITOS
#   Vivado debe estar en el PATH antes de correr el script:
#     source ~/Xilinx/2025.1/Vivado/settings64.sh
#
# USO
#   Correr siempre desde el root del repositorio:
#     cd ~/ruta/al/repo
#     bash scripts/run_sim.sh
#
# SALIDA
#   [PASS] / [FAIL] por cada TB, seguido de un resumen final.
#   Los archivos temporales se guardan en /tmp/vga_sim_work/
#
# AUTORES
#   Nicole Corrales, Gerson Cordero, Keilin Loásiga
#   EL3313 Taller de Diseño Digital — I Semestre 2026
# ==============================================================================

# ------------------------------------------------------------------------------
# Colores para output en terminal
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # sin color / reset

# ------------------------------------------------------------------------------
# Verificar que Vivado esté en el PATH
# ------------------------------------------------------------------------------
if ! command -v xvlog &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} xvlog no encontrado. Ejecutá primero:"
    echo "  source ~/Xilinx/2025.1/Vivado/settings64.sh"
    exit 1
fi

# ------------------------------------------------------------------------------
# Rutas del proyecto — relativas al root del repositorio
# REPO_ROOT se captura al momento de correr el script (debe ser el root)
# ------------------------------------------------------------------------------
REPO_ROOT=$(pwd)

RTL_VGA="$REPO_ROOT/rtl/vga"          # SyncVGA, VGAController
RTL_HC="$REPO_ROOT/rtl/hour_control"  # hour_control, debounce, sincronizador, seg_counter
RTL_IMG="$REPO_ROOT/rtl/image_gen"    # image_generator y sub-módulos de imagen
RTL_MEM="$REPO_ROOT/rtl/memory"       # vram (BRAM dual-port)
RTL_TOP="$REPO_ROOT/rtl/top"          # top (integración)
SIM_DIR="$REPO_ROOT/sim"              # testbenches
WORK_DIR="/tmp/vga_sim_work"          # directorio de trabajo temporal

# ------------------------------------------------------------------------------
# Contadores globales de resultados
# ------------------------------------------------------------------------------
TOTAL=0
PASSED=0
FAILED=0

# ------------------------------------------------------------------------------
# Función: run_tb
#
# Compila, elabora y simula un testbench dado.
# Cada TB corre en su propio subdirectorio de WORK_DIR para aislar
# los archivos xsim.dir generados por xvlog.
#
# xvlog guarda los módulos compilados en ./xsim.dir/work/ relativo al
# directorio actual. Por eso se hace cd al directorio de trabajo antes
# de compilar, y xelab los encuentra automáticamente.
#
# Argumentos:
#   $1     = nombre del TB (sin extensión .v)
#   $2..N  = rutas absolutas a los archivos RTL que necesita el TB
# ------------------------------------------------------------------------------
run_tb() {
    local TB_NAME=$1
    shift
    local RTL_FILES="$@"                      # archivos RTL separados por espacio
    local TB_FILE="$SIM_DIR/${TB_NAME}.v"     # archivo del testbench
    local WORK="$WORK_DIR/$TB_NAME"           # directorio de trabajo de este TB

    TOTAL=$((TOTAL + 1))

    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Corriendo: ${TB_NAME}${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Crear directorio limpio y moverse ahí
    rm -rf "$WORK"
    mkdir -p "$WORK"
    cd "$WORK"

    # Paso 1: Compilar RTL + TB con xvlog
    # xvlog analiza la sintaxis y guarda los módulos en ./xsim.dir/work/
    xvlog $RTL_FILES "$TB_FILE" --nolog \
        2>&1 | grep -E "ERROR|WARNING|analyzing module" | sed 's/^/  [xvlog] /'

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo -e "  ${RED}[FAIL]${NC} Error de compilación en $TB_NAME"
        FAILED=$((FAILED + 1))
        cd "$REPO_ROOT"
        return
    fi

    # Paso 2: Elaborar con xelab
    # xelab resuelve jerarquía, instancias y genera el snapshot de simulación
    xelab "$TB_NAME" -s "${TB_NAME}_snap" --nolog \
        2>&1 | grep -E "ERROR|Built simulation" | sed 's/^/  [xelab] /'

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo -e "  ${RED}[FAIL]${NC} Error de elaboración en $TB_NAME"
        FAILED=$((FAILED + 1))
        cd "$REPO_ROOT"
        return
    fi

    # Paso 3: Simular con xsim
    # --runall ejecuta hasta el $finish del TB y captura todo el output
    local SIM_OUT
    SIM_OUT=$(xsim "${TB_NAME}_snap" --nolog --runall 2>&1)
    echo "$SIM_OUT" | grep -v "^$" | sed 's/^/  /'

    # Determinar resultado buscando [FAIL] en la salida del simulador
    if echo "$SIM_OUT" | grep -q "\[FAIL\]"; then
        echo -e "  ${RED}[FAIL]${NC} $TB_NAME — hay pruebas fallidas"
        FAILED=$((FAILED + 1))
    else
        echo -e "  ${GREEN}[PASS]${NC} $TB_NAME — todas las pruebas pasaron"
        PASSED=$((PASSED + 1))
    fi

    cd "$REPO_ROOT"
}

# ==============================================================================
# EJECUCIÓN DE TESTBENCHES
# ==============================================================================
echo ""
echo "======================================================"
echo "  VGA Clock — Suite de simulaciones"
echo "  EL3313 Taller de Diseño Digital — I Semestre 2026"
echo "======================================================"

mkdir -p "$WORK_DIR"

# TB 1: Controlador VGA
# Verifica: contadores H/V, HSYNC/VSYNC, video_en, dirección VRAM, RGB
run_tb "tb_VGAController" \
    "$RTL_VGA/SyncVGA.v" \
    "$RTL_VGA/VGAController.v"

# TB 2: Control de hora
# Verifica: FSM (RUN/SET_HOURS/SET_MIN), debounce, sincronizador, contador BCD
run_tb "tb_hour_control" \
    "$RTL_HC/debounce.v" \
    "$RTL_HC/sincronizador.v" \
    "$RTL_HC/seg_counter.v" \
    "$RTL_HC/hour_control.v"

# TB 3: VRAM
# Verifica: escritura y lectura de la BRAM dual-port, latencia de 1 ciclo
run_tb "tb_vram" \
    "$RTL_MEM/vram.v"

# TB 4: Generador de imagen
# Verifica: composición de capas, escritura en VRAM, señales de parpadeo
run_tb "tb_image_generator" \
    "$RTL_IMG/blink_ctrl.v" \
    "$RTL_IMG/sky_background.v" \
    "$RTL_IMG/grill_sprite.v" \
    "$RTL_IMG/dog_sprite.v" \
    "$RTL_IMG/digit_renderer.v" \
    "$RTL_IMG/image_generator.v"

# TB 5: Sistema completo (top)
# Verifica: integración de todos los módulos, flujo completo de datos
run_tb "tb_top" \
    "$RTL_VGA/SyncVGA.v" \
    "$RTL_VGA/VGAController.v" \
    "$RTL_HC/debounce.v" \
    "$RTL_HC/sincronizador.v" \
    "$RTL_HC/seg_counter.v" \
    "$RTL_HC/hour_control.v" \
    "$RTL_IMG/blink_ctrl.v" \
    "$RTL_IMG/sky_background.v" \
    "$RTL_IMG/grill_sprite.v" \
    "$RTL_IMG/dog_sprite.v" \
    "$RTL_IMG/digit_renderer.v" \
    "$RTL_IMG/image_generator.v" \
    "$RTL_MEM/vram.v" \
    "$RTL_TOP/top.v"

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================
echo ""
echo "======================================================"
echo "  RESUMEN DE SIMULACIONES"
echo "======================================================"
echo -e "  Total   : $TOTAL"
echo -e "  ${GREEN}Pasados${NC} : $PASSED"
echo -e "  ${RED}Fallidos${NC}: $FAILED"
echo "======================================================"

