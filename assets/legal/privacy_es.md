# Política de privacidad (BORRADOR)

Vigencia: {{effectiveDate}}. Este texto es un borrador técnico que describe lo que hace la app. No es asesoramiento legal y debe revisarlo un abogado antes de publicarse.

## Responsable

{{controllerName}}, CUIT {{controllerTaxId}}, con domicilio en {{controllerAddress}}. Contacto para temas de datos personales: {{privacyEmail}}.

## Dónde se guardan tus datos

La app no tiene un servidor propio. Tu cuenta, tu perfil, tus looks guardados y tu foto de perfil se guardan solo en este teléfono, en el almacenamiento privado de la app. No los enviamos a ningún servidor nuestro.

## Qué datos usamos y para qué

- Cuenta: email, nombre, fecha de nacimiento y una contraseña que se guarda transformada (hash PBKDF2), nunca en texto claro. Sirven para abrir tu cuenta en este teléfono y para calcular tu edad.
- Perfil (opcional): tipo y tono de piel y gustos de maquillaje. Sirven para personalizar la app. [REVISAR: si el tono de piel puede considerarse dato sensible según el art. 2 de la Ley 25.326 y qué consentimiento requiere.]
- Foto de perfil (opcional): la elegís de tu galería. La guardamos achicada y sin metadatos (ubicación, cámara, fecha) en la carpeta de la app.
- Cámara en vivo: la imagen se procesa en el teléfono para ubicar puntos de la cara (ojos, labios, contorno) y dibujar el maquillaje virtual. No se graban fotos ni videos, no se envían a ningún lado y no se usan para reconocer quién sos: no se crean plantillas para identificar personas.
- Guía de maquillaje: mide colores y posiciones de tu cara en el teléfono durante la sesión. No se guarda ninguna imagen.
- Fotos de referencia y de producto (Studio): se analizan en el teléfono y solo quedan números (colores e intensidades). La foto no se guarda ni se sube. Usá fotos tuyas o con permiso de la persona que aparece.
- Looks guardados y "Mis looks": las recetas de maquillaje que guardás.

## Terceros que reciben datos

- Compras VIP: los pagos los procesa Google Play o la App Store; la app no ve los datos de tu tarjeta. Para saber si tenés VIP usamos RevenueCat, Inc., que recibe un identificador aleatorio de tu cuenta (no tu email ni tu nombre), los datos de la compra y datos técnicos del dispositivo. [REVISAR: transferencia internacional de datos (art. 12 Ley 25.326) y contrato con el proveedor.]
- Tipografías: la app descarga sus fuentes de los servidores de Google Fonts la primera vez que las usa. Google recibe la dirección IP y datos técnicos del pedido.
- Imágenes y videos del catálogo: si un look tiene una imagen o un video alojado en internet, el servidor que lo aloja recibe tu dirección IP al mostrarlo.
- Copia de seguridad del sistema: si tenés activada la copia de seguridad de Android o de iCloud, el sistema operativo puede incluir los datos de la app en tu copia, bajo tu cuenta de Google o de Apple.

No vendemos tus datos ni los usamos para publicidad. La app no incluye herramientas de analítica ni de publicidad.

## Consentimiento

Al crear la cuenta aceptás esta política. Podés retirar tu consentimiento en cualquier momento borrando tu cuenta. [REVISAR: forma del consentimiento según los arts. 5 y 6 de la Ley 25.326.]

## Cuánto tiempo se guardan

- En el teléfono: mientras exista tu cuenta. Al borrar la cuenta se borran tu perfil, tu foto, tus looks guardados y "Mis looks". Si desinstalás la app, el sistema borra sus datos.
- RevenueCat y las tiendas conservan los registros de compras según sus propias políticas. Para pedir que se borren, escribinos a {{privacyEmail}}. [COMPLETAR: plazo y procedimiento acordados con RevenueCat.]

## Tus derechos

Podés acceder a tus datos, rectificarlos, actualizarlos y pedir que se borren (arts. 14, 15 y 16 de la Ley 25.326):

- Desde la app: Perfil > Privacidad y datos (ver y copiar tus datos), Editar perfil (corregir) y Configuración de la cuenta > Eliminar cuenta (borrar).
- Por email a {{privacyEmail}}.

El titular de los datos personales tiene la facultad de ejercer el derecho de acceso a los mismos en forma gratuita a intervalos no inferiores a seis meses, salvo que se acredite un interés legítimo al efecto conforme lo establecido en el artículo 14, inciso 3 de la Ley N° 25.326. La Agencia de Acceso a la Información Pública, en su carácter de Órgano de Control de la Ley N° 25.326, tiene la atribución de atender las denuncias y reclamos que interpongan quienes resulten afectados en sus derechos por incumplimiento de las normas vigentes en materia de protección de datos personales. [REVISAR: texto vigente de la leyenda exigida por la AAIP e inscripción de la base de datos en el Registro Nacional.]

## Menores de edad

Para crear una cuenta hay que tener al menos {{minimumAge}} años. [REVISAR: edad mínima, consentimiento de padres o tutores (art. 26 del Código Civil y Comercial) y Ley 26.061.]

## Seguridad

Los datos están en el almacenamiento privado de la app, al que otras apps no pueden acceder. La contraseña se guarda con hash y sal. La base de datos del teléfono no está cifrada aparte: si alguien desbloquea tu teléfono o lo accede con permisos de administrador (root), podría leerla. Usá un bloqueo de pantalla.

## Cambios

Si cambiamos esta política, vamos a publicar la nueva versión con su fecha de vigencia. [REVISAR: cómo se avisa y si hay que volver a pedir la aceptación; hoy la app no guarda qué versión aceptaste.]

## Contacto

{{controllerName}} · {{privacyEmail}} · Soporte: {{supportContact}}
