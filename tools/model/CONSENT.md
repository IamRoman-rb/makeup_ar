# Protocolo de recolección de caras (fase 3)

Antes de grabar a nadie para entrenar el modelo propio. Las caras son datos personales sensibles (biométricos).

> **No soy abogado.** Esto es un punto de partida técnico y ético, no asesoramiento legal. En Argentina aplica la Ley 25.326 de Protección de Datos Personales (y lo que la reemplace): consultá con un abogado antes de empezar, en particular sobre el registro de la base ante la autoridad de control y sobre menores (no grabar menores de 18).

## Reglas

1. **Consentimiento previo, informado, por escrito y revocable.** Cada persona firma el release de abajo antes de grabar. Sin `consent_id` en el manifiesto, el video no se usa (`dataset.py` lo rechaza).
2. **Finalidad única.** Las imágenes sirven solo para entrenar y evaluar el modelo de landmarks faciales de la app. No se publican, no se venden, no se usan para reconocer personas ni para publicidad.
3. **Minimización.** Se graba solo la cara, sin audio. En el manifiesto va un id seudónimo (`s001`), nunca el nombre. La tabla id ↔ persona y los releases firmados se guardan aparte de los videos, con acceso restringido.
4. **Nada sale del equipo de entrenamiento.** Los videos, los cuadros y las etiquetas viven fuera del repo (`teacher_label.py` se niega a escribir dentro). No se suben a la nube sin cifrar ni a servicios de terceros. Las caras de usuarios de la app **nunca** entran en este set.
5. **Revocación.** Si alguien revoca, su `consent_id` va a `revoked.txt`: queda fuera de todo desde el próximo entrenamiento. Se borran sus videos, cuadros y etiquetas en un plazo de 30 días. Los modelos ya entrenados con esos datos se reentrenan en el siguiente ciclo.
6. **Retención.** Los datos crudos se borran al cerrar la fase 3 o a los 2 años, lo que pase primero. Se conservan solo los pesos del modelo, que no contienen imágenes.
7. **Diversidad documentada.** Hay que cubrir los 6 tonos de Fitzpatrick (autodeclarado) y las luces (`neutral`, `warm`, `cool`, `low`, `outdoor`, `backlight`). `dataset.coverage()` cuenta personas por tono y por luz; si un tono tiene muchas menos personas, el modelo hereda el sesgo. Por eso el NME se reporta por tono.

## Qué grabar por persona (≈ 5 minutos)

- 30 s de cara quieta mirando a la cámara, en cada luz disponible (`"static": true`, para el jitter).
- 60 s girando la cabeza despacio (izquierda, derecha, arriba, abajo, hasta ~45°).
- 30 s hablando y sonriendo (labios en movimiento).
- 30 s parpadeando y mirando a los costados (iris).
- Con y sin maquillaje si la persona quiere (labial oscuro, delineado), con anteojos si los usa.
- Celular de gama baja (idealmente el E20) a la distancia de uso real (30-60 cm).

## Release (plantilla)

> Yo, ______________________ (DNI ____________), acepto que [responsable del proyecto] grabe videos de mi cara para **entrenar y evaluar un modelo de detección de puntos faciales** de la app makeup_ar.
>
> - Los videos no se publican ni se comparten con terceros, y no se usan para identificarme.
> - Se guardan con un código en lugar de mi nombre y se borran a más tardar el ___/___/____.
> - Puedo retirar este consentimiento cuando quiera escribiendo a __________________; en ese caso borran mis videos en 30 días y dejan de usarlos.
> - Declaro tener 18 años o más.
> - Tono de piel (autodeclarado, Fitzpatrick 1-6, opcional): ____
>
> Código asignado (lo completa el responsable): `C-____-____` · Fecha: ___/___/____ · Firma: ______________
