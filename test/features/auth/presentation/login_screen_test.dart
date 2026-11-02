import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/auth/data/drift_auth_repository.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/auth/domain/password_hasher.dart';
import 'package:ar_makeup_app/features/auth/presentation/login_screen.dart';
import 'package:ar_makeup_app/features/catalog/presentation/catalog_screen.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:ar_makeup_app/shared/data/local_db/app_database.dart';
import '../../../helpers/memory_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  late AppDatabase db;
  late DriftAuthRepository auth;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    db = memoryDatabaseForWidgets();
    auth = DriftAuthRepository(db, hasher: const PasswordHasher(iterations: 1));
    AppServices.useForTesting(database: db, auth: auth);
  });
  tearDown(() => db.close());

  Widget app() => MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      );

  testWidgets('contraseña incorrecta: avisa y no abre sesión', (tester) async {
    await tester.runAsync(() async {
      await auth.signUp(email: 'ana@mail.com', password: 'secreta', profile: const UserProfile(name: 'Ana'));
      await auth.signOut();
    });
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@mail.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'mala123');
    await tester.tap(find.byType(ElevatedButton));
    // El hash corre en otro isolate: hace falta tiempo real.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('contraseña correcta: abre sesión y va al catálogo', (tester) async {
    await tester.runAsync(() async {
      await auth.signUp(email: 'ana@mail.com', password: 'secreta', profile: const UserProfile(name: 'Ana'));
      await auth.signOut();
    });
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextFormField).at(0), ' ANA@mail.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secreta');
    await tester.tap(find.byType(ElevatedButton));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(auth.currentUser?.email, 'ana@mail.com');
    expect(find.byType(CatalogScreen), findsOneWidget);
    // Cierra las suscripciones de drift antes de terminar el test.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  });
}
