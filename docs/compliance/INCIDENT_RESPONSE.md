# Respuesta a incidentes de seguridad y datos personales (borrador)

**Estado:** borrador técnico. El responsable, los plazos de aviso y la comunicación a la AAIP y a los usuarios los define el operador con un abogado (Ley 25.326 art. 9 y normativa de la AAIP sobre incidentes de seguridad). `[COMPLETAR: responsable del incidente y contacto]`.

## 1. Superficie actual

Sin servidor propio, los datos de las cuentas están en cada teléfono. Los incidentes posibles hoy son:

| Escenario | Impacto | Qué hacer |
|---|---|---|
| Key de RevenueCat filtrada (`env/revenuecat.json`) | Las keys públicas (`goog_`/`appl_`) son para el cliente; una secret key (`sk_`) **nunca** debe estar en el repo ni en la app | Rotar en el panel de RevenueCat; si fue una secret key, revisar el historial de cambios de suscriptores |
| Keystore de release o `key.properties` filtrados | Alguien podría firmar actualizaciones | Con Play App Signing: pedir el reemplazo de la upload key en Play Console. Sin él, no hay recuperación: por eso Play App Signing es obligatorio en el checklist |
| Secreto commiteado (`.env`, keys) | Exposición pública (el repo es público) | Revocar primero; después limpiar el historial (`git filter-repo`) coordinado con quien tenga clones |
| Vulnerabilidad en una dependencia | Según el caso | `flutter pub outdated`, actualizar, publicar versión |
| Bug que exponga datos entre cuentas del mismo teléfono | Otra persona del mismo dispositivo ve datos | Corregir, publicar, avisar en la ficha si corresponde |
| Problema en RevenueCat o una tienda | Datos de compra en un tercero | Seguir la comunicación del proveedor; evaluar aviso a usuarios |

## 2. Pasos

1. **Detectar y registrar**: qué, cuándo, cómo se supo. Guardar evidencia sin copiar datos personales a canales inseguros.
2. **Contener**: revocar/rotar credenciales, despublicar una versión, desactivar la offering de RevenueCat si hace falta.
3. **Evaluar**: qué datos, cuántas personas, riesgo. Recordar que fotos y cámara no salen del teléfono (`DATA_INVENTORY.md`).
4. **Notificar**: a la AAIP y a las personas afectadas según lo que defina el abogado. `[COMPLETAR: plazo y canal]`.
5. **Corregir y documentar**: causa, cambio, test que lo cubre, fecha.

## 3. Contactos

- Responsable: `[COMPLETAR]`
- Abogado: `[COMPLETAR]`
- RevenueCat (soporte del panel), Google Play Console, App Store Connect.
