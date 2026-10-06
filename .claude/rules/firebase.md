---
paths:
  - "firestore.rules"
  - "functions/**"
---
# Firebase y Cloud Functions
- Ninguna key ni secreto en el repo: Secret Manager para las functions.
- Toda entrada del cliente se valida en la función con el mismo esquema JSON que usa la app.
- Las reglas de Firestore se prueban con el emulador antes de proponer cambios.
- Cambios en `firestore.rules` o en cuotas: plan primero y pedir confirmación.
