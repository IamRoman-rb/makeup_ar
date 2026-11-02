/// Datos del responsable de la app que aparecen en la política de privacidad,
/// los términos y el centro de privacidad (docs/compliance/RELEASE_CHECKLIST.md).
///
/// Nada de esto se inventa: lo completa el operador al compilar, igual que las
/// keys de RevenueCat, con un JSON local:
///
///     flutter build appbundle --dart-define-from-file=env/legal.json
///
/// Plantilla en `env/legal.example.json`. Un campo vacío se muestra como
/// `[COMPLETAR: …]` y la app marca los textos como BORRADOR.
library;

/// Un dato del responsable: clave del `--dart-define`, etiqueta para el
/// marcador y valor (vacío si falta).
final class LegalField {
  const LegalField(this.key, this.label, this.value);

  /// Nombre de la variable de `--dart-define` y del marcador `{{key}}` en las
  /// plantillas de `assets/legal/`.
  final String key;

  /// Qué tiene que completar el operador (en español: es para él, no para el
  /// usuario final).
  final String label;
  final String value;

  bool get isMissing => value.trim().isEmpty;

  /// Valor, o el marcador visible si falta.
  String get display => isMissing ? LegalInfo.placeholder(label) : value.trim();
}

final class LegalInfo {
  const LegalInfo({
    this.controllerName = '',
    this.controllerTaxId = '',
    this.controllerAddress = '',
    this.privacyEmail = '',
    this.supportContact = '',
    this.jurisdiction = '',
    this.effectiveDate = '',
    this.minimumAge = 0,
    this.reviewedByCounsel = false,
  });

  /// Lo que entró por `--dart-define` (vacío si no se pasó nada).
  const LegalInfo.fromEnvironment()
      : controllerName = const String.fromEnvironment('LEGAL_CONTROLLER_NAME'),
        controllerTaxId = const String.fromEnvironment('LEGAL_CONTROLLER_TAX_ID'),
        controllerAddress = const String.fromEnvironment('LEGAL_CONTROLLER_ADDRESS'),
        privacyEmail = const String.fromEnvironment('LEGAL_PRIVACY_EMAIL'),
        supportContact = const String.fromEnvironment('LEGAL_SUPPORT_CONTACT'),
        jurisdiction = const String.fromEnvironment('LEGAL_JURISDICTION'),
        effectiveDate = const String.fromEnvironment('LEGAL_EFFECTIVE_DATE'),
        minimumAge = const int.fromEnvironment('LEGAL_MINIMUM_AGE'),
        reviewedByCounsel = const bool.fromEnvironment('LEGAL_REVIEWED');

  /// Razón social o nombre del responsable de los datos.
  final String controllerName;

  /// CUIT/CUIL del responsable.
  final String controllerTaxId;

  /// Domicilio legal del responsable.
  final String controllerAddress;

  /// Email para ejercer los derechos de la Ley 25.326 (acceso, rectificación,
  /// supresión).
  final String privacyEmail;

  /// Canal de soporte y reclamos de consumo (email, web o teléfono).
  final String supportContact;

  /// Ley aplicable y tribunales (lo define un abogado).
  final String jurisdiction;

  /// Fecha de vigencia de los textos.
  final String effectiveDate;

  /// Edad mínima para crear una cuenta; 0 = todavía no la definió el operador.
  final int minimumAge;

  /// Un abogado revisó los textos finales. Sin esto quedan como borrador
  /// aunque estén todos los datos.
  final bool reviewedByCounsel;

  /// Marcador visible para un dato que falta.
  static String placeholder(String label) => '[COMPLETAR: $label]';

  List<LegalField> get fields => [
        LegalField('controllerName', 'razón social o nombre del responsable', controllerName),
        LegalField('controllerTaxId', 'CUIT del responsable', controllerTaxId),
        LegalField('controllerAddress', 'domicilio legal del responsable', controllerAddress),
        LegalField('privacyEmail', 'email para ejercer derechos sobre datos personales', privacyEmail),
        LegalField('supportContact', 'canal de soporte y reclamos', supportContact),
        LegalField('jurisdiction', 'ley aplicable y jurisdicción (definir con un abogado)', jurisdiction),
        LegalField('effectiveDate', 'fecha de vigencia', effectiveDate),
        LegalField('minimumAge', 'edad mínima (decisión del operador con un abogado)',
            minimumAge > 0 ? '$minimumAge' : ''),
      ];

  List<LegalField> get missingFields => [for (final field in fields) if (field.isMissing) field];

  /// Todos los datos cargados y revisados por un abogado: recién ahí los
  /// textos dejan de mostrarse como borrador.
  bool get isFinal => missingFields.isEmpty && reviewedByCounsel;

  /// Reemplaza `{{clave}}` por el valor o por el marcador. Las claves
  /// desconocidas quedan a la vista como marcador (nunca texto vacío).
  String render(String template) {
    final values = {for (final field in fields) field.key: field.display};
    return template.replaceAllMapped(
      RegExp(r'\{\{(\w+)\}\}'),
      (match) => values[match.group(1)] ?? placeholder('${match.group(1)}'),
    );
  }
}

/// Resultado del control de edad del registro.
enum AgeCheck {
  /// Cumple la edad mínima, o el operador todavía no la definió.
  allowed,

  /// No llega a la edad mínima configurada.
  underMinimum,

  /// Falta la fecha de nacimiento.
  missingBirthDate,
}

abstract final class AgePolicy {
  /// Años cumplidos en [now].
  static int ageAt(DateTime birthDate, DateTime now) {
    var age = now.year - birthDate.year;
    final hadBirthday = now.month > birthDate.month || (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age < 0 ? 0 : age;
  }

  /// Con [minimumAge] 0 (sin definir) no bloquea: la decisión es del operador
  /// y queda como bloqueo de lanzamiento en el checklist.
  static AgeCheck check({required DateTime? birthDate, required DateTime now, required int minimumAge}) {
    if (birthDate == null) return AgeCheck.missingBirthDate;
    if (minimumAge <= 0) return AgeCheck.allowed;
    return ageAt(birthDate, now) >= minimumAge ? AgeCheck.allowed : AgeCheck.underMinimum;
  }
}
