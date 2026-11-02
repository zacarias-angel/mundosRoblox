# Respaldos de la recuperación — 2026-11-02

| Carpeta | Contenido |
|---|---|
| `before_hitos_0_1_2026_11_02` | 31 fuentes anteriores a modificar y manifiesto de escena |
| `after_hitos_0_1_2026_11_02` | 34 fuentes finales y manifiesto de escena/configuración |
| `qa_hito1_final_2026_11_02` | Resultados de la validación final y scripts temporales que la ejecutaron |
| `qa_hito1_first_pass_2026_11_02` | Primera pasada y hallazgos antes de corregir aplazamiento de IA |
| `qa_hito1_rare_defeat_2026_11_02` | Derrota legítima del solver en encuentro raro, útil para balance posterior |

Las fuentes se guardan como archivos numerados `.luau`; `manifest.json` conserva sus rutas originales de Studio. Las rutas pueden incluir puntos dentro del nombre del script: usar los nombres reales del Explorer, no separar automáticamente todos los puntos como carpetas.

El snapshot de instancias previo está en `ServerStorage/RecoveryBackups/Before_Hitos_0_1_2026_11_02`. Sus scripts se guardaron desactivados y el atributo `RecoveryOriginalDisabled` indica su estado previo.

**Estos archivos no son un place binario.** Los manifiestos contienen referencias a assets, no mallas ni texturas embebidas, y no exportan voxels de Terrain. Guardar el place en Studio conserva la escena y el respaldo interno.

Los scripts `RecoveryQA` pertenecen al instrumental de prueba. No insertarlos como parte del juego publicado; el harness principal está conservado en `../tools/playtest_recovery.server.luau` y requiere Studio.

Registro completo: [sesión de recuperación](../docs/SESION_2026-11-02_HITOS_0_1.md).
