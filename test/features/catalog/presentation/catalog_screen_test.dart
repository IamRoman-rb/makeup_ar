import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/auth/data/drift_auth_repository.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/auth/domain/password_hasher.dart';
import 'package:ar_makeup_app/features/catalog/data/catalog_seed.dart';
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
    db = memoryDatabaseForWidgets(seed: CatalogSeed.insertPresets);
    auth = DriftAuthRepository(db, hasher: const PasswordHasher(iterations: 1));
    AppServices.useForTesting(database: db, auth: auth);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CatalogScreen(),
    ));
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    // Cierra las suscripciones de drift antes de terminar el test.
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  Future<void> signUp(WidgetTester tester, String email) => tester.runAsync(
        () => auth.signUp(email: email, password: 'secreta', profile: const UserProfile(name: 'Ana')),
      );

  testWidgets('muestra los presets sembrados y el corazón guarda el look', (tester) async {
    await signUp(tester, 'ana@mail.com');
    await open(tester);

    final first = RecipePresets.all.first.recipe.name;
    expect(find.text(first), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await settle(tester);
    final saved = await tester.runAsync(() => AppServices.savedLooks.watchSavedIds(auth.currentUser?.id ?? '').first);
    expect(saved, {CatalogSeed.idFor(RecipePresets.all.first.id)});
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await close(tester);
  });

  testWidgets('el botón de crear look aparece solo para el admin (la primera cuenta)', (tester) async {
    await signUp(tester, 'ana@mail.com');
    await open(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await close(tester);

    await tester.runAsync(auth.signOut);
    await signUp(tester, 'bea@mail.com');
    await open(tester);
    expect(find.byType(FloatingActionButton), findsNothing);
    await close(tester);
  });

  testWidgets('la búsqueda filtra por nombre', (tester) async {
    await signUp(tester, 'ana@mail.com');
    await open(tester);
    final target = RecipePresets.all.last.recipe.name;
    await tester.enterText(find.byType(TextField), target.toLowerCase());
    await tester.pump();
    expect(find.text(target), findsOneWidget);
    expect(find.text(RecipePresets.all.first.recipe.name), findsNothing);
    await close(tester);
  });
}
