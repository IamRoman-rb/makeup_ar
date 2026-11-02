import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/auth/data/drift_auth_repository.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/auth/domain/password_hasher.dart';
import 'package:ar_makeup_app/features/auth/presentation/auth_messages.dart';
import 'package:ar_makeup_app/features/profile/presentation/account_settings_screen.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import '../../../helpers/memory_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('cada falla de la cuenta tiene su texto', () async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    final texts = {for (final failure in AuthFailure.values) authFailureText(es, failure)};
    expect(texts, hasLength(AuthFailure.values.length));
    expect(authFailureText(es, AuthFailure.weakPassword), contains('${AuthRules.minPasswordLength}'));
  });

  testWidgets('el diálogo de cambio de contraseña devuelve la actual y la nueva', (tester) async {
    ({String current, String next})? result;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog(context: context, builder: (_) => const ChangePasswordDialog()),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('current-password')), 'vieja12 ');
    await tester.enterText(find.byKey(const ValueKey('new-password')), 'nueva123');
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    expect(result?.current, 'vieja12');
    expect(result?.next, 'nueva123');
  });

  testWidgets('la pantalla de cuenta muestra el email de la sesión', (tester) async {
    final db = memoryDatabaseForWidgets();
    final auth = DriftAuthRepository(db, hasher: const PasswordHasher(iterations: 1));
    AppServices.useForTesting(database: db, auth: auth);
    await tester.runAsync(
      () => auth.signUp(email: 'ana@mail.com', password: 'secreta', profile: const UserProfile(name: 'Ana')),
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AccountSettingsScreen(),
    ));
    expect(find.text('ana@mail.com'), findsOneWidget);
    expect(auth.currentUser, isNotNull);
    await tester.runAsync(db.close);
  });
}
