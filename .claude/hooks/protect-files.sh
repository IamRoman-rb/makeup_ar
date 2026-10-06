#!/bin/bash
# Bloquea ediciones (Edit/Write) de archivos sensibles.
# Sin dependencia de jq (no está instalado en esta PC): extrae tool_input.file_path con grep/sed.
INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -n 1 \
  | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')
# Normaliza separadores de Windows (en JSON llegan como \\) a "/" y colapsa duplicados.
FILE_PATH=$(printf '%s' "$FILE_PATH" | tr '\\' '/' | sed -E 's#/+#/#g')

# Si no se pudo leer la ruta, se bloquea (falla cerrada) en lugar de dejar pasar en silencio.
if [[ -z "$FILE_PATH" ]]; then
  echo "Bloqueado: protect-files.sh no pudo leer tool_input.file_path" >&2
  exit 2
fi

PROTECTED_PATTERNS=(".env" "google-services.json" "GoogleService-Info.plist" "key.properties" ".jks" "revenue_cat_keys.dart" ".git/")

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "Bloqueado: $FILE_PATH coincide con el patrón protegido '$pattern'" >&2
    exit 2
  fi
done
exit 0
