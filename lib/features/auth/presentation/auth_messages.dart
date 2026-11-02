import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';

/// Texto de una falla de la cuenta local.
String authFailureText(AppLocalizations l10n, AuthFailure failure) => switch (failure) {
      AuthFailure.invalidEmail => l10n.authErrorInvalidEmail,
      AuthFailure.weakPassword => l10n.authErrorWeakPassword(AuthRules.minPasswordLength),
      AuthFailure.emailInUse => l10n.authErrorEmailInUse,
      AuthFailure.wrongCredentials => l10n.authErrorWrongCredentials,
      AuthFailure.notSignedIn => l10n.loginFirst,
    };
