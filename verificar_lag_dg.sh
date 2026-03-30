#!/usr/bin/env bash
#
# verificar_lag_dg.sh
#
# Monitoreo de retraso de aplicación en Oracle Data Guard
# - Conecta al standby
# - Lee value y time_computed de v$dataguard_stats (name = 'apply lag')
# - Convierte el valor a segundos
# - Imprime retraso y estado
#

# Umbrales en segundos
UMBRAL_ADVERTENCIA=60      # 1 minuto
UMBRAL_CRITICO=300         # 5 minutos

CADENA_CONEXION="$1"

salir_error() {
  echo "ERROR: $1"
  exit 1
}

verificar_entorno() {
  if ! command -v sqlplus >/dev/null 2>&1; then
    salir_error "sqlplus no encontrado en PATH. Configure ORACLE_HOME y PATH."
  fi

  if [ -z "$CADENA_CONEXION" ] && [ -z "$ORACLE_SID" ]; then
    salir_error "ORACLE_SID no definido y no se proporcionó cadena de conexión."
  fi
}

ejecutar_sql() {
  if [ -n "$CADENA_CONEXION" ]; then
    sqlplus -s "$CADENA_CONEXION" <<'EOF'
SET PAGES 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF LINES 200 COLSEP '|' TRIMSPOOL ON
SELECT value, time_computed
  FROM v$dataguard_stats
 WHERE name = 'apply lag';
EXIT
EOF
  else
    sqlplus -s "/ as sysdba" <<'EOF'
SET PAGES 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF LINES 200 COLSEP '|' TRIMSPOOL ON
SELECT value, time_computed
  FROM v$dataguard_stats
 WHERE name = 'apply lag';
EXIT
EOF
  fi
}

########################################
# Principal
########################################

verificar_entorno

RESULTADO="$(ejecutar_sql)"

# Quitar lineas vacias y tomar solo la primera
RESULTADO="$(echo "$RESULTADO" | sed '/^$/d' | head -n 1)"

# Si viene ORA-*, mostrar y salir
if echo "$RESULTADO" | grep -q "ORA-"; then
  echo "$RESULTADO"
  salir_error "Error de Oracle al consultar v\$dataguard_stats."
fi

if [ -z "$RESULTADO" ]; then
  salir_error "No se encontró información de APPLY LAG en v\$dataguard_stats."
fi

# Formato esperado:
# +00 00:00:00|12/11/2025 17:42:56
VALOR_LAG="${RESULTADO%%|*}"
HORA_CONSULTA="${RESULTADO#*|}"

# Limpiar espacios
VALOR_LAG="$(echo "$VALOR_LAG" | xargs)"
HORA_CONSULTA="$(echo "$HORA_CONSULTA" | xargs)"

if [ -z "$VALOR_LAG" ]; then
  salir_error "No se pudo interpretar el valor de apply lag."
fi

# Quitar '+' inicial si existe
LAG_LIMPIO="${VALOR_LAG#+}"

# Quitar fracción (.000) si existe
LAG_LIMPIO="${LAG_LIMPIO%%.*}"

# Puede venir como "00 00:00:00" (DD HH:MI:SS) o "00:00:00" (HH:MI:SS)
read -r PRIMERO SEGUNDO <<< "$LAG_LIMPIO"

if [ -z "$SEGUNDO" ]; then
  # Formato HH:MI:SS
  DIAS=0
  HMS="$PRIMERO"
else
  # Formato DD HH:MI:SS
  DIAS="$PRIMERO"
  HMS="$SEGUNDO"
fi

IFS=':' read -r HORA MIN SEG <<< "$HMS"

DIAS=${DIAS:-0}
HORA=${HORA:-0}
MIN=${MIN:-0}
SEG=${SEG:-0}

# Convertir a entero (forzando base 10)
DIAS=$((10#$DIAS))
HORA=$((10#$HORA))
MIN=$((10#$MIN))
SEG=$((10#$SEG))

TOTAL_SEGUNDOS=$(( SEG + MIN*60 + HORA*3600 + DIAS*86400 ))

ESTADO="OK"
if [ "$TOTAL_SEGUNDOS" -ge "$UMBRAL_CRITICO" ]; then
  ESTADO="CRITICO"
elif [ "$TOTAL_SEGUNDOS" -ge "$UMBRAL_ADVERTENCIA" ]; then
  ESTADO="ADVERTENCIA"
fi

echo "Retraso Aplicacion : $VALOR_LAG"
echo "Hora Consulta      : $HORA_CONSULTA"
echo "Retraso (segundos) : $TOTAL_SEGUNDOS"
echo "Estado             : $ESTADO"

if [ "$ESTADO" = "OK" ]; then
  exit 0
elif [ "$ESTADO" = "ADVERTENCIA" ]; then
  exit 1
elif [ "$ESTADO" = "CRITICO" ]; then
  exit 2
else
  exit 3
fi
