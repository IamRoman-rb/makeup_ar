import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/auth/data/drift_auth_repository.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/auth/domain/password_hasher.dart';
import 'package:ar_makeup_app/features/legal/domain/legal_document.dart';
import 'package:ar_makeup_app/features/legal/domain/legal_info.dart';
import 'package:ar_makeup_app/features/legal/presentation/legal_document_screen.dart';
import 'package:ar_makeup_app/features/legal/presentation/privacy_center_screen.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../helpers/memory_database.dart';

Widget _app(Widget home, {Locale locale = const Locale('es')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('documento: carga el idioma de la app, completa marcadores y muestra BORRADOR', (tester) async {
    final requested = <String>[];
    await tester.pumpWidget(_app(
      LegalDocumentScreen(
        kind: LegalDocumentKind.privacy,
        info: const LegalInfo(controllerName: 'Empresa de Prueba SA'),
        loader: (path) async {
          requested.add(path);
          return '# Política\n\n## Responsable\n\n{{controllerName}} · {{privacyEmail}}';
        },
      ),
      locale: const Locale('pt'),
    ));
    await tester.pumpAndSettle();
    expect(requested, ['assets/legal/privacy_pt.md']);
    expect(find.textContaining('RASCUNHO'), findsOneWidget);
    expect(find.textContaining('Empresa de Prueba SA · [COMPLETAR: email'), findsOneWidget);
  });

  testWidgets('centro de privacidad: datos de la cuenta, contacto y enlaces', (tester) async {
    final db = memoryDatabaseForWidgets();
    addTearDown(db.close);
    final auth = DriftAuthRepository(db, hasher: const PasswordHasher(iterations: 1));
    AppServices.useForTesting(database: db, auth: auth);
    await tester.runAsync(
      () => auth.signUp(email: 'ana@mail.com', password: 'secreta', profile: const UserProfile(name: 'Ana')),
    );
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const PrivacyCenterScreen(info: LegalInfo())));
    await tester.pump();
    expect(find.text('ana@mail.com'), findsOneWidget);
    expect(find.textContaining('BORRADOR'), findsOneWidget);
    expect(find.textContaining('[COMPLETAR: email para ejercer derechos'), findsOneWidget);
    for (final label in ['Política de privacidad', 'Términos y condiciones', 'Gestionar o cancelar la suscripción', 'Eliminar Cuenta', 'Licencias de terceros']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
