// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'App Maquillaje AR';

  @override
  String get discoverLooks => 'Descubrir Looks';

  @override
  String get searchHint => 'Busca filtros o marcas...';

  @override
  String get categoryAll => 'Todo';

  @override
  String get categoryLips => 'Labios';

  @override
  String get categoryEyes => 'Ojos';

  @override
  String get categoryComplexion => 'Rostro';

  @override
  String noLooksFound(Object category) {
    return 'No se encontraron looks en la categoría $category.';
  }

  @override
  String noResultsFor(Object category, Object query) {
    return 'No hay resultados para \"$query\" en $category.';
  }

  @override
  String get welcomeBack => 'Bienvenido de nuevo';

  @override
  String get loginSubtitle => 'Ingresa tus datos para iniciar sesión.';

  @override
  String get emailOrUser => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get logIn => 'INICIAR SESIÓN';

  @override
  String get noAccount => '¿No tienes una cuenta? ';

  @override
  String get signUp => 'Regístrate';

  @override
  String get createProfile => 'Crea tu Perfil';

  @override
  String get joinSubtitle =>
      'Únete a Lumière Beauty para una experiencia cosmética única.';

  @override
  String get fullName => 'Nombre y Apellido';

  @override
  String get email => 'Correo Electrónico';

  @override
  String get age => 'Edad';

  @override
  String get dob => 'Fecha de Nacimiento';

  @override
  String get skinType => 'Tipo de Piel';

  @override
  String get skinTone => 'Tono de Piel';

  @override
  String get personalTastes => 'Gustos Personales';

  @override
  String get createAccount => 'Crear Cuenta';

  @override
  String get editProfile => 'Editar Perfil';

  @override
  String get updateProfile => 'Actualizar Perfil';

  @override
  String get skinTypeLabel => 'TIPO PIEL';

  @override
  String get toneLabel => 'TONO';

  @override
  String get savedLooks => 'Looks\nGuardados';

  @override
  String get tutorials => 'Tutoriales';

  @override
  String get favorites => 'Favoritos';

  @override
  String get mySavedLooks => 'Mis Looks Guardados';

  @override
  String get viewAll => 'Ver Todos >';

  @override
  String get settings => 'Configuración';

  @override
  String get accountSettings => 'Ajustes de la cuenta';

  @override
  String get appLanguage => 'Idioma de la app';

  @override
  String get logOut => 'Cerrar Sesión';

  @override
  String get security => 'Seguridad';

  @override
  String get changePassword => 'Cambiar Contraseña';

  @override
  String get changePasswordDesc => 'Enviaremos un enlace a tu correo.';

  @override
  String get sendLink => 'Enviar Enlace';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get pushNotif => 'Notificaciones Push';

  @override
  String get pushNotifDesc => 'Alertas sobre nuevos looks y funciones.';

  @override
  String get emailNotif => 'Boletín por Correo';

  @override
  String get emailNotifDesc => 'Inspiración y tips de belleza semanales.';

  @override
  String get dangerZone => 'Zona de Peligro';

  @override
  String get deleteAccount => 'Eliminar Cuenta';

  @override
  String get deleteAccountDesc =>
      'Una vez que elimines tu cuenta, no hay vuelta atrás. Por favor, asegúrate.';

  @override
  String get deleteMyAccountBtn => 'Eliminar Mi Cuenta';

  @override
  String get selectLanguageTitle => 'Idioma / Language';

  @override
  String get selectLanguageDesc =>
      'Selecciona tu idioma preferido para la aplicación.';

  @override
  String get saved => 'Guardado';

  @override
  String get save => 'Guardar';

  @override
  String get tutorial => 'Tutorial';

  @override
  String get effectOn => 'Efecto Act.';

  @override
  String get effectOff => 'Efecto Inact.';

  @override
  String get profileUpdated => '¡Perfil actualizado con éxito!';

  @override
  String get errorSaving => 'Error al guardar:';

  @override
  String get loginFirst => 'Por favor, inicia sesión primero.';

  @override
  String get noSavedLooks =>
      'Aún no has guardado ningún look.\n¡Explora el catálogo para encontrar tus favoritos!';

  @override
  String get unknownLook => 'Look desconocido';

  @override
  String get explore => 'Explorar';

  @override
  String get profile => 'Perfil';

  @override
  String get mirror => 'Espejo';

  @override
  String get testFilter => 'Filtro de prueba';

  @override
  String get testFilterNone => 'Sin filtro';

  @override
  String get testFilterIntensity => 'Intensidad';

  @override
  String get testFilterNote =>
      'Motor nuevo (beta): cada look se aplica completo con seguimiento facial. La primera vez tarda unos segundos en cargar.';

  @override
  String get testFilterShowPoints => 'Ver puntos';

  @override
  String get testFilterZoneAll => 'Todo';

  @override
  String get testFilterZoneLips => 'Labios';

  @override
  String get testFilterZoneEyes => 'Ojos';

  @override
  String get testFilterZoneCheeks => 'Mejillas';

  @override
  String get testFilterZoneSkin => 'Piel';

  @override
  String get testFilterUnavailable =>
      'El maquillaje en vivo no está disponible en este equipo. Se muestra el espejo normal.';

  @override
  String get testFilterCompare => 'Mantené para comparar';

  @override
  String get testFilterFinishMatte => 'Mate';

  @override
  String get testFilterFinishSatin => 'Satinado';

  @override
  String get testFilterFinishGloss => 'Brillo';

  @override
  String get testFilterFinishShimmer => 'Shimmer';

  @override
  String get fillRequiredFields =>
      'Por favor completa todos los campos requeridos';

  @override
  String get registrationError => 'Error de registro';

  @override
  String get stepByStepTitle => 'Guía Paso a Paso';

  @override
  String get stepLabel => 'PASO';

  @override
  String get backBtn => 'Atrás';

  @override
  String get finishBtn => 'Terminar';

  @override
  String get nextStepBtn => 'Siguiente';

  @override
  String get tutStep1Title => 'Luminous Foundation';

  @override
  String get tutStep1Desc =>
      'Aplica unas gotas de la base en el centro de tu rostro. Difumina hacia afuera usando una brocha o esponja húmeda para lograr un acabado natural, radiante y uniforme.';

  @override
  String get tutStep2Title => 'Velvet Liquid Blush';

  @override
  String get tutStep2Desc =>
      'Coloca tres pequeños puntos de rubor líquido en los pómulos altos. Difumina rápidamente con ligeros toques hacia las sienes para conseguir un efecto lifting espectacular.';

  @override
  String get tutStep3Title => 'Gold Highlighter';

  @override
  String get tutStep3Desc =>
      'Aplica suavemente el iluminador en los puntos altos de tu rostro: parte superior de los pómulos, puente de la nariz y arco de cupido para un brillo deslumbrante.';

  @override
  String get tryOnAr => 'Probar en AR';

  @override
  String get studioTitle => 'Studio IA';

  @override
  String get studioMenuStudio => 'Crear con IA (Studio)';

  @override
  String get studioMenuSteps => 'Editar pasos del tutorial';

  @override
  String get studioPromptHint =>
      'Describí el look (ej.: labios góticos y rubor naranja)';

  @override
  String get studioGenerate => 'Generar';

  @override
  String get studioRemixHint => 'Ajuste (ej.: más natural, tonos más cálidos)';

  @override
  String get studioRemix => 'Remix';

  @override
  String get studioNote =>
      'Studio: elegí una variante y ajustala antes de publicar.';

  @override
  String get studioEmpty => 'Escribí un pedido y tocá Generar.';

  @override
  String get studioSaveDraft => 'Guardar borrador';

  @override
  String get studioPublish => 'Publicar';

  @override
  String get studioDrafts => 'Borradores';

  @override
  String get studioNoDrafts => 'No hay borradores.';

  @override
  String get studioDeleteDraft => 'Borrar borrador';

  @override
  String get studioSaved => 'Borrador guardado.';

  @override
  String get studioPublished => 'Look publicado en el catálogo.';

  @override
  String get studioSaveError => 'No se pudo guardar. Revisá la conexión.';

  @override
  String get studioName => 'Nombre';

  @override
  String get studioCategory => 'Categoría';

  @override
  String get studioImageUrl => 'URL de la imagen (opcional)';

  @override
  String get studioCancel => 'Cancelar';

  @override
  String get studioAccept => 'Aceptar';

  @override
  String get studioRemove => 'Quitar';

  @override
  String get studioColorHex => 'Color (#RRGGBB)';

  @override
  String get studioFinish => 'Acabado';

  @override
  String get studioLayerLips => 'Labial';

  @override
  String get studioLayerLipLiner => 'Delineado de labios';

  @override
  String get studioLayerCheeks => 'Rubor';

  @override
  String get studioLayerFoundation => 'Base';

  @override
  String get studioLayerContour => 'Contorno';

  @override
  String get studioLayerHighlight => 'Iluminador';

  @override
  String get studioLayerEyeLiner => 'Delineado';

  @override
  String get studioLayerLashes => 'Pestañas';

  @override
  String studioLayerShadow(int index) {
    return 'Sombra $index';
  }

  @override
  String get studioFallback =>
      'La IA no devolvió variantes válidas: se muestra el preset más parecido.';

  @override
  String get studioErrorAuth => 'Iniciá sesión para usar el Studio.';

  @override
  String get studioErrorAdmin =>
      'Solo los administradores pueden generar looks.';

  @override
  String get studioErrorInput =>
      'El pedido tiene que tener entre 1 y 300 caracteres.';

  @override
  String get studioErrorQuota => 'Se agotó la cuota de hoy. Probá mañana.';

  @override
  String get studioErrorUnavailable =>
      'El generador no responde. Probá de nuevo en un rato.';

  @override
  String get studioErrorAppCheck =>
      'La app no pasó la verificación (App Check).';

  @override
  String get studioErrorUnknown => 'No se pudo generar.';
}
