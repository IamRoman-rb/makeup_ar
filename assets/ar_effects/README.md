# Efecto base de DeepAR

Acá va `makeup_base.deepar`, el efecto paramétrico creado una sola vez en
[DeepAR Studio](https://www.deepar.ai/studio), que `DeepArMakeupEngine`
(`lib/ar/deepar_makeup_engine.dart`) carga con `switchEffect()` y después
ajusta en vivo con `changeParameter()` según la receta que genera el prompt
de IA (Groq/Llama3). No hace falta editar nada por look: el prompt sigue
generando la misma receta JSON de siempre, y el motor la traduce a llamadas
`changeParameter` sobre este efecto.

## Qué tiene que tener el efecto

Un game object por feature, cada uno con un material/color ajustable en
runtime. Los nombres exactos deben coincidir con las constantes de
`lib/ar/deepar_node_mapping.dart`:

- `Lips`
- `Blush`
- `Eyeshadow`
- `Eyeliner`
- `Eyelashes`
- `Foundation`
- `Glow`

Si en Studio les ponés otros nombres, actualizá esas mismas constantes en
`deepar_node_mapping.dart` — es el único lugar que hay que tocar.

## Mientras este archivo no exista

`ArEngineConfig.useDeepAr` (en `lib/ar/ar_engine_config.dart`) está en
`false`, así que la app sigue usando el motor legacy (ML Kit + CustomPainter)
sin tocar DeepAR. Una vez que copies `makeup_base.deepar` acá, cambiá esa
constante a `true` para activar el motor nuevo.
