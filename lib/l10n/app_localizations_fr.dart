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
  String get mirror => 'Miroir';

  @override
  String get testFilter => 'Filtre de test';

  @override
  String get testFilterNone => 'Sans filtre';

  @override
  String get testFilterIntensity => 'Intensité';

  @override
  String get testFilterNote =>
      'Nouveau moteur (bêta) : chaque look est appliqué en entier avec le suivi du visage. La première fois, le chargement prend quelques secondes.';

  @override
  String get testFilterShowPoints => 'Voir les points';

  @override
  String get testFilterZoneAll => 'Tout';

  @override
  String get testFilterZoneLips => 'Lèvres';

  @override
  String get testFilterZoneEyes => 'Yeux';

  @override
  String get testFilterZoneCheeks => 'Joues';

  @override
  String get testFilterZoneSkin => 'Peau';

  @override
  String get testFilterUnavailable =>
      'Le maquillage en direct n\'est pas disponible sur cet appareil. Affichage du miroir normal.';

  @override
  String get testFilterCompare => 'Maintenir pour comparer';

  @override
  String get testFilterFinishMatte => 'Mat';

  @override
  String get testFilterFinishSatin => 'Satiné';

  @override
  String get testFilterFinishGloss => 'Brillant';

  @override
  String get testFilterFinishShimmer => 'Scintillant';

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

  @override
  String get tryOnAr => 'Essayer en RA';

  @override
  String get studioTitle => 'Studio IA';

  @override
  String get studioMenuStudio => 'Créer avec l\'IA (Studio)';

  @override
  String get studioMenuSteps => 'Modifier les étapes du tutoriel';

  @override
  String get studioPromptHint =>
      'Décrivez le look (ex. : lèvres gothiques et blush orange)';

  @override
  String get studioGenerate => 'Générer';

  @override
  String get studioRemixHint =>
      'Ajustement (ex. : plus naturel, tons plus chauds)';

  @override
  String get studioRemix => 'Remix';

  @override
  String get studioNote =>
      'Studio : choisissez une variante et ajustez-la avant de publier.';

  @override
  String get studioEmpty => 'Écrivez une demande et touchez Générer.';

  @override
  String get studioSaveDraft => 'Enregistrer le brouillon';

  @override
  String get studioPublish => 'Publier';

  @override
  String get studioDrafts => 'Brouillons';

  @override
  String get studioNoDrafts => 'Aucun brouillon.';

  @override
  String get studioDeleteDraft => 'Supprimer le brouillon';

  @override
  String get studioSaved => 'Brouillon enregistré.';

  @override
  String get studioPublished => 'Look publié dans le catalogue.';

  @override
  String get studioSaveError =>
      'Échec de l\'enregistrement. Vérifiez la connexion.';

  @override
  String get studioName => 'Nom';

  @override
  String get studioCategory => 'Catégorie';

  @override
  String get studioImageUrl => 'URL de l\'image (facultatif)';

  @override
  String get studioCancel => 'Annuler';

  @override
  String get studioAccept => 'OK';

  @override
  String get studioRemove => 'Retirer';

  @override
  String get studioColorHex => 'Couleur (#RRGGBB)';

  @override
  String get studioFinish => 'Fini';

  @override
  String get studioLayerLips => 'Rouge à lèvres';

  @override
  String get studioLayerLipLiner => 'Crayon à lèvres';

  @override
  String get studioLayerCheeks => 'Blush';

  @override
  String get studioLayerFoundation => 'Fond de teint';

  @override
  String get studioLayerContour => 'Contouring';

  @override
  String get studioLayerHighlight => 'Enlumineur';

  @override
  String get studioLayerEyeLiner => 'Eye-liner';

  @override
  String get studioLayerLashes => 'Cils';

  @override
  String studioLayerShadow(int index) {
    return 'Fard $index';
  }

  @override
  String get studioFallback =>
      'L\'IA n\'a renvoyé aucune variante valide : affichage du preset le plus proche.';

  @override
  String get studioErrorAuth => 'Connectez-vous pour utiliser le Studio.';

  @override
  String get studioErrorAdmin =>
      'Seuls les administrateurs peuvent générer des looks.';

  @override
  String get studioErrorInput =>
      'La demande doit contenir entre 1 et 300 caractères.';

  @override
  String get studioErrorQuota =>
      'Le quota du jour est épuisé. Réessayez demain.';

  @override
  String get studioErrorUnavailable =>
      'Le générateur ne répond pas. Réessayez plus tard.';

  @override
  String get studioErrorAppCheck =>
      'L\'app n\'a pas passé la vérification (App Check).';

  @override
  String get studioErrorUnknown => 'Échec de la génération.';

  @override
  String get studioFromPhoto => 'Depuis une photo';

  @override
  String get studioPalette => 'Palette produit';

  @override
  String get studioPhotoNoticeTitle => 'Photo de référence';

  @override
  String get studioPhotoNotice =>
      'La photo est analysée sur ce téléphone : elle n’est ni envoyée ni enregistrée. Utilisez vos propres photos ou des photos autorisées par la personne qui y figure.';

  @override
  String get studioContinue => 'Continuer';

  @override
  String get studioPhotoNoFace => 'Aucun visage trouvé sur la photo.';

  @override
  String get studioPhotoSmall =>
      'Le visage est trop petit : utilisez une photo plus rapprochée.';

  @override
  String get studioPhotoProfile =>
      'Le visage est tourné : utilisez une photo de face.';

  @override
  String get studioPhotoBad => 'La photo n’a pas pu être analysée.';

  @override
  String get studioPhotoFaithful => 'Photo · fidèle';

  @override
  String get studioPhotoBolder => 'Photo · intense';

  @override
  String get studioPhotoSubtler => 'Photo · subtile';

  @override
  String get studioPhotoRough =>
      'Correspondance approximative : vérifiez les couleurs dans l’aperçu.';

  @override
  String studioRegionConfidence(String layer, int percent) {
    return '$layer : $percent %';
  }

  @override
  String get studioPaletteEmpty => 'Aucune couleur trouvée sur la photo.';

  @override
  String get studioPalettePickLayer => 'Où va cette couleur ?';

  @override
  String get studioNewShadow => 'Nouvelle ombre';

  @override
  String get studioQaTitle => 'Contrôle qualité';

  @override
  String get studioQaVisibility => 'Visibilité';

  @override
  String get studioQaClipping => 'Saturation';

  @override
  String get studioQaConsistency => 'Teintes de peau';

  @override
  String get studioQaCoverage => 'Couvrance';

  @override
  String get studioQaCost => 'Performance';

  @override
  String get studioQaOk => 'OK';

  @override
  String get studioQaCostOk =>
      'Dans les limites mesurées sur le téléphone de référence';

  @override
  String studioQaInvisible(String layer) {
    return '$layer : invisible sur toutes les peaux';
  }

  @override
  String studioQaSubtle(String layer) {
    return '$layer : à peine visible';
  }

  @override
  String studioQaWashedOut(String layer) {
    return '$layer : couleur très saturée, délavée à la lumière';
  }

  @override
  String studioQaChalky(String layer) {
    return '$layer : aspect plâtreux sur peau foncée';
  }

  @override
  String studioQaAshy(String layer) {
    return '$layer : aspect cendré sur peau foncée';
  }

  @override
  String studioQaFades(String layer) {
    return '$layer : invisible sur certaines teintes';
  }

  @override
  String get studioQaExtremeLiner => 'Eye-liner et wing au maximum';

  @override
  String get studioQaMaskFoundation =>
      'Fond de teint très couvrant (effet masque)';

  @override
  String get studioQaHeavyBlush => 'Blush très grand et intense';

  @override
  String get studioQaEffects =>
      '3 effets à la fois : non mesuré sur le téléphone de référence';

  @override
  String get studioQaBlocked => 'Corrigez les points en rouge pour publier.';

  @override
  String get studioLayerIris => 'Iris (lentilles de couleur)';

  @override
  String get myAiLooksTitle => 'Mes looks IA';

  @override
  String get myAiLooksPromptHint =>
      'Décrivez le look (ex. : lèvres rouges et eye-liner graphique)';

  @override
  String myAiLooksDailyLimit(int count) {
    return 'Jusqu\'à $count par jour';
  }

  @override
  String get myAiLooksGenerate => 'Générer';

  @override
  String get myAiLooksVariants => 'Choisissez une variante';

  @override
  String get myAiLooksSuggestion => 'Suggestion';

  @override
  String get myAiLooksTry => 'Essayer';

  @override
  String get myAiLooksSave => 'Enregistrer';

  @override
  String get myAiLooksSaved => 'Enregistré dans vos looks';

  @override
  String get myAiLooksSavedTitle => 'Enregistrés';

  @override
  String get myAiLooksEmpty => 'Vous n\'avez encore enregistré aucun look IA.';

  @override
  String get myAiLooksDelete => 'Supprimer';

  @override
  String myAiLooksDeleteConfirm(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String myAiLooksErrorQuota(int count) {
    return 'Vous avez atteint la limite de $count looks pour aujourd\'hui. Réessayez demain.';
  }

  @override
  String myAiLooksErrorFull(int count) {
    return 'Vous avez déjà $count looks enregistrés. Supprimez-en un pour en ajouter un autre.';
  }

  @override
  String get myAiLooksErrorLogin => 'Connectez-vous pour créer des looks.';

  @override
  String get myAiLooksErrorGeneric => 'Impossible de terminer. Réessayez.';

  @override
  String get myAiLooksFallback =>
      'L\'IA n\'a pas répondu : voici un look similaire.';

  @override
  String myAiLooksInvalidPrompt(int max) {
    return 'Écrivez entre 1 et $max caractères.';
  }

  @override
  String loginError(String details) {
    return 'Connexion impossible : $details';
  }

  @override
  String errorWithDetails(String details) {
    return 'Erreur : $details';
  }

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get catalogCreateLookTooltip => 'Créer un look (admin)';

  @override
  String catalogLoadError(String details) {
    return 'Impossible de charger les looks : $details';
  }

  @override
  String get filterEditorNewTitle => 'Nouveau look';

  @override
  String get filterEditorEditTitle => 'Modifier le look';

  @override
  String get filterEditorDefaultName => 'Nouveau look';

  @override
  String get filterEditorSaved => 'Look enregistré ! 🚀';

  @override
  String filterEditorSaveError(String details) {
    return 'Impossible d\'enregistrer le look : $details';
  }

  @override
  String get filterEditorDeleteTitle => 'Supprimer le look ?';

  @override
  String get filterEditorDeleteBody => 'Cette action est irréversible.';

  @override
  String get filterEditorDeleted => 'Look supprimé 🗑️';

  @override
  String get filterEditorAdminOnly =>
      'Seul un administrateur peut créer ou modifier des looks.';

  @override
  String get filterEditorDeleteTooltip => 'Supprimer le look';

  @override
  String get filterEditorName => 'Nom du look';

  @override
  String get filterEditorCategory => 'Catégorie';

  @override
  String get filterEditorCoverUrl =>
      'URL de l\'image de couverture (facultatif)';

  @override
  String get filterEditorVideoUrl =>
      'URL de la vidéo du tutoriel (facultatif, VIP uniquement)';

  @override
  String get filterEditorSteps => 'Étapes du tutoriel';

  @override
  String get filterEditorAddStep => 'Ajouter une étape';

  @override
  String get filterEditorNoSteps => 'Aucune étape pour l\'instant.';

  @override
  String filterEditorStep(int number) {
    return 'Étape $number';
  }

  @override
  String get filterEditorRemoveStep => 'Supprimer l\'étape';

  @override
  String get filterEditorStepTitle => 'Titre';

  @override
  String get filterEditorStepImage => 'URL de l\'image (facultatif)';

  @override
  String get filterEditorStepDescription => 'Description / instructions';

  @override
  String get stepsEmpty => 'Il n\'y a pas encore d\'étapes pour ce look.';

  @override
  String get tutorialNoVideoTitle => 'Pas de vidéo pour ce look';

  @override
  String get tutorialNoVideoBody =>
      'Nous n\'avons pas encore de vidéo pour ce tutoriel.';

  @override
  String get tutorialVipTitle => 'Tutoriel VIP';

  @override
  String get tutorialVipBody => 'Découvrez les secrets de ce look.';

  @override
  String get becomeVip => 'Devenez VIP';

  @override
  String passwordEmailSent(String email) {
    return 'E-mail envoyé à $email';
  }

  @override
  String get passwordEmailError => 'Impossible d\'envoyer l\'e-mail.';

  @override
  String get deleteAccountReauth =>
      'Déconnectez-vous puis reconnectez-vous avant de supprimer votre compte.';

  @override
  String profileLoadError(String details) {
    return 'Impossible de charger le profil : $details';
  }

  @override
  String get profileNoData => 'Données du profil introuvables.';

  @override
  String profilePreferences(String list) {
    return 'Préférences : $list';
  }

  @override
  String get profileDefaultBio =>
      'À la découverte d\'esthétiques élégantes et minimalistes.';

  @override
  String get skinTypeCombined => 'Mixte';

  @override
  String get skinTypeOily => 'Grasse';

  @override
  String get skinTypeDry => 'Sèche';

  @override
  String get skinTypeSensitive => 'Sensible';

  @override
  String get skinToneLight => 'Claire';

  @override
  String get skinToneMedium => 'Moyenne';

  @override
  String get skinToneTan => 'Mate';

  @override
  String get skinToneDeep => 'Foncée';

  @override
  String get prefNatural => 'Naturel';

  @override
  String get prefGlamour => 'Glamour';

  @override
  String get prefMinimalist => 'Minimaliste';

  @override
  String get prefBold => 'Audacieux';

  @override
  String get prefSkincare => 'Soin de la peau';

  @override
  String get vipUnavailable =>
      'Le VIP n\'est pas disponible dans cette version.';

  @override
  String vipLoadError(String details) {
    return 'Impossible de charger les offres VIP.\n$details';
  }

  @override
  String get vipPurchased =>
      'C\'est fait, vous êtes VIP ! 🎉 Activation dans quelques secondes.';

  @override
  String vipPurchaseError(String details) {
    return 'Impossible de finaliser l\'achat : $details';
  }

  @override
  String get vipRestored =>
      'Abonnement VIP retrouvé ! 🎉 Activation dans quelques secondes.';

  @override
  String get vipNothingToRestore => 'Aucun achat à restaurer.';

  @override
  String get vipRestore => 'Restaurer les achats';

  @override
  String get vipNoPlans => 'Aucune offre VIP n\'est encore configurée.';

  @override
  String get vipHeadline => 'Débloquez les vidéos de tous les tutoriels';

  @override
  String get signupPhotoFailed =>
      'Votre compte a été créé, mais la photo n\'a pas pu être envoyée. Vous pourrez l\'ajouter plus tard depuis votre profil.';

  @override
  String get startupError =>
      'Impossible de démarrer l\'application. Vérifiez votre connexion.';

  @override
  String get commonRetry => 'Réessayer';
}
