# Monitor de Retraso de Aplicación en Data Guard

## Para qué sirve

Script de shell que revisa el retraso de aplicación (apply lag) en bases de datos Oracle con Data Guard configurado. Lo hice porque necesitaba algo rápido para detectar cuándo el standby se queda atrás aplicando redo, sin depender de herramientas pesadas.

Consulta directamente `v$dataguard_stats`, convierte el resultado a segundos y te dice si el lag está dentro de lo aceptable o no.

## Qué hace

- Lee el apply lag en tiempo real desde `v$dataguard_stats`
- Funciona con Oracle RAC (multi-hilo) y configuraciones standalone
- Convierte el valor a segundos para comparar con umbrales configurables
- Devuelve códigos de salida compatibles con herramientas de monitoreo (0=OK, 1=WARNING, 2=CRITICAL)
- Se puede meter en un cron sin problemas

## Consulta que usa

```sql
SELECT value, time_computed
  FROM v$dataguard_stats
 WHERE name = 'apply lag';
```

## Requisitos

- Linux con Bash
- SQL*Plus instalado y configurado
- Variables de entorno de Oracle listas (`ORACLE_HOME`, `ORACLE_SID`, `PATH`)
- Un usuario con permisos para consultar vistas V$ (SYS, SYSDG, o uno con `SELECT_CATALOG_ROLE`)

## Cómo usarlo

Clonar el repositorio:

    git clone https://github.com/vida-rafael/monitor-retraso-aplicacion-dg.git
    cd monitor-retraso-aplicacion-dg

Editar las variables de conexión dentro del script:

    vi verificar_lag_dg.sh

Dar permisos de ejecución:

    chmod +x verificar_lag_dg.sh

Ejecutar:

    ./verificar_lag_dg.sh
    # o con connect string:
    ./verificar_lag_dg.sh "sys/password@TNS_STANDBY as sysdba"

## Ejemplo de salida

    Retraso Aplicacion : +00 00:00:02
    Hora Consulta      : 2025-12-10 14:33:21
    Retraso (segundos) : 2
    Estado             : OK

Si el lag pasa de los umbrales definidos, el código de salida cambia y se puede usar para disparar alertas.

## Archivos

    monitor-retraso-aplicacion-dg/
    ├── verificar_lag_dg.sh
    └── README.md

## Notas

Lo uso en ambientes con Exadata donde el Data Guard es parte central de la estrategia de contingencia. Es liviano y no cambia nada en la base, solo lee vistas de performance.

## Licencia

MIT License
