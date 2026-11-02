import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/auth/data/drift_auth_repository.dart';
import 'package:ar_makeup_app/features/auth/domain/password_hasher.dart';
import 'package:ar_makeup_app/features/auth/presentation/signup_screen.dart';
import 'package:ar_makeup_app/features/legal/domain/legal_info.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../helpers/memory_database.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<DriftAuthRepository> pumpSignUp(WidgetTester tester, {int minimumAge = 0}) async {
    final db = memoryDatabaseForWidgets();
    addTearDown(db.close);
    final auth = DriftAuthRepository(db, hasher: const PasswordHasher(iterations: 1));
    AppServices.useForTesting(database: db, auth: auth);
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SignUpScreen(legalInfo: LegalInfo(minimumAge: minimumAge), clock: () => DateTime(2026, 11, 2)),
    ));
    return auth;
  }

  Future<void> fillForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'ana@mail.com');
    await tester.enterText(fields.at(2), 'secreta');
    // Fecha: el selector arranca en 2000-01-01.
    await tester.tap(find.text('mm/dd/yyyy'));
    await tester.pumpAndSettle();
    final ok = MaterialLocalizations.of(tester.element(find.byType(SignUpScreen))).okButtonLabel;
    await tester.tap(find.text(ok));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.byType(ElevatedButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('no pide la edad aparte de la fecha y muestra los enlaces legales', (tester) async {
    await pumpSignUp(tester);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Política de privacidad'), findsOneWidget);
    expect(find.text('Términos y condiciones'), findsOneWidget);
    expect(find.text('Opcional. Se guarda solo en este teléfono, achicada y sin datos de ubicación.'), findsOneWidget);
  });

  testWidgets('sin aceptar la política y los términos no se crea la cuenta', (tester) async {
    final auth = await pumpSignUp(tester);
    await fillForm(tester);
    await submit(tester);
    expect(find.text('Para crear la cuenta tenés que aceptar la política de privacidad y los términos.'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('con edad mínima configurada, bloquea a quien no la cumple', (tester) async {
    final auth = await pumpSignUp(tester, minimumAge: 30);
    await fillForm(tester);
    final accept = find.byKey(const ValueKey('accept-legal'));
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await tester.pump();
    await submit(tester);
    expect(find.text('Para crear una cuenta tenés que tener al menos 30 años.'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });
}
