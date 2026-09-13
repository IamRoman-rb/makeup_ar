// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'App Maquillage AR';

  @override
  String get discoverLooks => 'Découvrir des Looks';

  @override
  String get searchHint => 'Rechercher des filtres ou marques...';

  @override
  String get categoryAll => 'Tout';

  @override
  String get categoryLips => 'Lèvres';

  @override
  String get categoryEyes => 'Yeux';

  @override
  String get categoryComplexion => 'Teint';

  @override
  String noLooksFound(Object category) {
    return 'Aucun look trouvé dans la catégorie $category.';
  }

  @override
  String noResultsFor(Object category, Object query) {
    return 'Aucun résultat pour \"$query\" dans $category.';
  }

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get loginSubtitle =>
      'Veuillez entrer vos identifiants pour vous connecter.';

  @override
  String get emailOrUser => 'E-mail ou Utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get logIn => 'CONNEXION';

  @override
  String get noAccount => 'Vous n\'avez pas de compte ? ';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get createProfile => 'Créez votre Profil';

  @override
  String get joinSubtitle =>
      'Rejoignez Lumière Beauty pour une expérience cosmétique unique.';

  @override
  String get fullName => 'Nom Complet';

  @override
  String get email => 'Adresse E-mail';

  @override
  String get age => 'Âge';

  @override
  String get dob => 'Date de Naissance';

  @override
  String get skinType => 'Type de Peau';

  @override
  String get skinTone => 'Teint de Peau';

  @override
  String get personalTastes => 'Goûts Personnels';

  @override
  String get createAccount => 'Créer un Compte';

  @override
  String get editProfile => 'Modifier le Profil';

  @override
  String get updateProfile => 'Mettre à jour le Profil';

  @override
  String get skinTypeLabel => 'TYPE DE PEAU';

  @override
  String get toneLabel => 'TEINT';

  @override
  String get savedLooks => 'Looks\nSauvegardés';

  @override
  String get tutorials => 'Tutoriels';

  @override
  String get favorites => 'Favoris';

  @override
  String get mySavedLooks => 'Mes Looks Sauvegardés';

  @override
  String get viewAll => 'Voir Tout >';

  @override
  String get settings => 'Paramètres';

  @override
  String get accountSettings => 'Paramètres du Compte';

  @override
  String get appLanguage => 'Langue de l\'app';

  @override
  String get logOut => 'Se Déconnecter';

  @override
  String get security => 'Sécurité';

  @override
  String get changePassword => 'Changer le Mot de Passe';

  @override
  String get changePasswordDesc =>
      'Nous enverrons un lien de réinitialisation sur votre e-mail.';

  @override
  String get sendLink => 'Envoyer le Lien';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotif => 'Notifications Push';

  @override
  String get pushNotifDesc =>
      'Alertes pour de nouveaux looks et fonctionnalités.';

  @override
  String get emailNotif => 'Newsletter par E-mail';

  @override
  String get emailNotifDesc =>
      'Conseils de beauté hebdomadaires et inspiration.';

  @override
  String get dangerZone => 'Zone de Danger';

  @override
  String get deleteAccount => 'Supprimer le Compte';

  @override
  String get deleteAccountDesc =>
      'Une fois votre compte supprimé, il n\'y a pas de retour en arrière. Soyez certain.';

  @override
  String get deleteMyAccountBtn => 'Supprimer Mon Compte';

  @override
  String get selectLanguageTitle => 'Langue / Language';

  @override
  String get selectLanguageDesc =>
      'Sélectionnez votre langue préférée pour l\'application.';

  @override
  String get saved => 'Sauvegardé';

  @override
  String get save => 'Sauvegarder';

  @override
  String get tutorial => 'Tutoriel';

  @override
  String get effectOn => 'Effet Act.';

  @override
  String get effectOff => 'Effet Désact.';

  @override
  String get profileUpdated => 'Profil mis à jour avec succès !';

  @override
  String get errorSaving => 'Erreur lors de la sauvegarde :';

  @override
  String get loginFirst => 'Veuillez d\'abord vous connecter.';

  @override
  String get noSavedLooks =>
      'Vous n\'avez pas encore sauvegardé de looks.\nExplorez le catalogue pour trouver vos favoris !';

  @override
  String get unknownLook => 'Look Inconnu';

  @override
  String get explore => 'Explorer';

  @override
  String get profile => 'Profil';

  @override
  String get fillRequiredFields =>
      'Veuillez remplir tous les champs obligatoires';

  @override
  String get registrationError => 'Erreur d\'inscription';

  @override
  String get stepByStepTitle => 'Guide Étape par Étape';

  @override
  String get stepLabel => 'ÉTAPE';

  @override
  String get backBtn => 'Retour';

  @override
  String get finishBtn => 'Terminer';

  @override
  String get nextStepBtn => 'Suivant';

  @override
  String get tutStep1Title => 'Luminous Foundation';

  @override
  String get tutStep1Desc =>
      'Appliquez quelques gouttes de fond de teint au centre de votre visage. Estompez vers l\'extérieur à l\'aide d\'un pinceau ou d\'une éponge humide pour une finition naturelle, éclatante et uniforme.';

  @override
  String get tutStep2Title => 'Velvet Liquid Blush';

  @override
  String get tutStep2Desc =>
      'Placez trois petits points de fard à joues liquide sur vos pommettes. Estompez rapidement par de légers tapotements vers vos tempes pour un effet lifting spectaculaire.';

  @override
  String get tutStep3Title => 'Gold Highlighter';

  @override
  String get tutStep3Desc =>
      'Appliquez doucement l\'illuminateur sur les points hauts de votre visage : haut des pommettes, arête du nez et arc de cupidon pour un éclat éblouissant.';
}
