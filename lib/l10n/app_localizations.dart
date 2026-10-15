import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AR Makeup App'**
  String get appTitle;

  /// No description provided for @discoverLooks.
  ///
  /// In en, this message translates to:
  /// **'Discover Looks'**
  String get discoverLooks;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for filters or brands...'**
  String get searchHint;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @categoryLips.
  ///
  /// In en, this message translates to:
  /// **'Lips'**
  String get categoryLips;

  /// No description provided for @categoryEyes.
  ///
  /// In en, this message translates to:
  /// **'Eyes'**
  String get categoryEyes;

  /// No description provided for @categoryComplexion.
  ///
  /// In en, this message translates to:
  /// **'Complexion'**
  String get categoryComplexion;

  /// No description provided for @noLooksFound.
  ///
  /// In en, this message translates to:
  /// **'No looks found in {category} category.'**
  String noLooksFound(Object category);

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\" in {category}.'**
  String noResultsFor(Object category, Object query);

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter your details to sign in.'**
  String get loginSubtitle;

  /// No description provided for @emailOrUser.
  ///
  /// In en, this message translates to:
  /// **'Email or Username'**
  String get emailOrUser;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'LOG IN'**
  String get logIn;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Your Profile'**
  String get createProfile;

  /// No description provided for @joinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join Lumière Beauty for a curated cosmetic experience.'**
  String get joinSubtitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get email;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @dob.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dob;

  /// No description provided for @skinType.
  ///
  /// In en, this message translates to:
  /// **'Skin Type'**
  String get skinType;

  /// No description provided for @skinTone.
  ///
  /// In en, this message translates to:
  /// **'Skin Tone'**
  String get skinTone;

  /// No description provided for @personalTastes.
  ///
  /// In en, this message translates to:
  /// **'Personal Tastes'**
  String get personalTastes;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @updateProfile.
  ///
  /// In en, this message translates to:
  /// **'Update Profile'**
  String get updateProfile;

  /// No description provided for @skinTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'SKIN TYPE'**
  String get skinTypeLabel;

  /// No description provided for @toneLabel.
  ///
  /// In en, this message translates to:
  /// **'TONE'**
  String get toneLabel;

  /// No description provided for @savedLooks.
  ///
  /// In en, this message translates to:
  /// **'Saved\nLooks'**
  String get savedLooks;

  /// No description provided for @tutorials.
  ///
  /// In en, this message translates to:
  /// **'Tutorials'**
  String get tutorials;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @mySavedLooks.
  ///
  /// In en, this message translates to:
  /// **'My Saved Looks'**
  String get mySavedLooks;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All >'**
  String get viewAll;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @changePasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'We will send a reset link to your email.'**
  String get changePasswordDesc;

  /// No description provided for @sendLink.
  ///
  /// In en, this message translates to:
  /// **'Send Link'**
  String get sendLink;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushNotif.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotif;

  /// No description provided for @pushNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'Alerts for new looks and features.'**
  String get pushNotifDesc;

  /// No description provided for @emailNotif.
  ///
  /// In en, this message translates to:
  /// **'Email Newsletters'**
  String get emailNotif;

  /// No description provided for @emailNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'Weekly beauty tips and inspiration.'**
  String get emailNotifDesc;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Once you delete your account, there is no going back. Please be certain.'**
  String get deleteAccountDesc;

  /// No description provided for @deleteMyAccountBtn.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteMyAccountBtn;

  /// No description provided for @selectLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language / Idioma'**
  String get selectLanguageTitle;

  /// No description provided for @selectLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language for the application.'**
  String get selectLanguageDesc;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @tutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get tutorial;

  /// No description provided for @effectOn.
  ///
  /// In en, this message translates to:
  /// **'Effect On'**
  String get effectOn;

  /// No description provided for @effectOff.
  ///
  /// In en, this message translates to:
  /// **'Effect Off'**
  String get effectOff;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdated;

  /// No description provided for @errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving:'**
  String get errorSaving;

  /// No description provided for @loginFirst.
  ///
  /// In en, this message translates to:
  /// **'Please log in first.'**
  String get loginFirst;

  /// No description provided for @noSavedLooks.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t saved any looks yet.\nExplore the catalog to find your favorites!'**
  String get noSavedLooks;

  /// No description provided for @unknownLook.
  ///
  /// In en, this message translates to:
  /// **'Unknown Look'**
  String get unknownLook;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @mirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get mirror;

  /// No description provided for @testFilter.
  ///
  /// In en, this message translates to:
  /// **'Test filter'**
  String get testFilter;

  /// No description provided for @testFilterNone.
  ///
  /// In en, this message translates to:
  /// **'No filter'**
  String get testFilterNone;

  /// No description provided for @testFilterIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get testFilterIntensity;

  /// No description provided for @testFilterNote.
  ///
  /// In en, this message translates to:
  /// **'New engine (beta): each look is applied in full with face tracking. The first time it takes a few seconds to load.'**
  String get testFilterNote;

  /// No description provided for @testFilterShowPoints.
  ///
  /// In en, this message translates to:
  /// **'Show points'**
  String get testFilterShowPoints;

  /// No description provided for @testFilterZoneAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get testFilterZoneAll;

  /// No description provided for @testFilterZoneLips.
  ///
  /// In en, this message translates to:
  /// **'Lips'**
  String get testFilterZoneLips;

  /// No description provided for @testFilterZoneEyes.
  ///
  /// In en, this message translates to:
  /// **'Eyes'**
  String get testFilterZoneEyes;

  /// No description provided for @testFilterZoneCheeks.
  ///
  /// In en, this message translates to:
  /// **'Cheeks'**
  String get testFilterZoneCheeks;

  /// No description provided for @testFilterZoneSkin.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get testFilterZoneSkin;

  /// No description provided for @testFilterUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live makeup isn\'t available on this device. Showing the regular mirror.'**
  String get testFilterUnavailable;

  /// No description provided for @testFilterCompare.
  ///
  /// In en, this message translates to:
  /// **'Hold to compare'**
  String get testFilterCompare;

  /// No description provided for @testFilterFinishMatte.
  ///
  /// In en, this message translates to:
  /// **'Matte'**
  String get testFilterFinishMatte;

  /// No description provided for @testFilterFinishSatin.
  ///
  /// In en, this message translates to:
  /// **'Satin'**
  String get testFilterFinishSatin;

  /// No description provided for @testFilterFinishGloss.
  ///
  /// In en, this message translates to:
  /// **'Gloss'**
  String get testFilterFinishGloss;

  /// No description provided for @testFilterFinishShimmer.
  ///
  /// In en, this message translates to:
  /// **'Shimmer'**
  String get testFilterFinishShimmer;

  /// No description provided for @fillRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields'**
  String get fillRequiredFields;

  /// No description provided for @registrationError.
  ///
  /// In en, this message translates to:
  /// **'Registration error'**
  String get registrationError;

  /// No description provided for @stepByStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Step-by-Step Guide'**
  String get stepByStepTitle;

  /// No description provided for @stepLabel.
  ///
  /// In en, this message translates to:
  /// **'STEP'**
  String get stepLabel;

  /// No description provided for @backBtn.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backBtn;

  /// No description provided for @finishBtn.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishBtn;

  /// No description provided for @nextStepBtn.
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get nextStepBtn;

  /// No description provided for @tutStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Luminous Foundation'**
  String get tutStep1Title;

  /// No description provided for @tutStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Apply a few drops of foundation to the center of your face. Blend outwards using a brush or damp sponge for a natural, radiant, and even finish.'**
  String get tutStep1Desc;

  /// No description provided for @tutStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Velvet Liquid Blush'**
  String get tutStep2Title;

  /// No description provided for @tutStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'Place three small dots of liquid blush on your high cheekbones. Blend quickly with light taps towards your temples for a spectacular lifting effect.'**
  String get tutStep2Desc;

  /// No description provided for @tutStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Gold Highlighter'**
  String get tutStep3Title;

  /// No description provided for @tutStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'Gently apply the highlighter to the high points of your face: tops of your cheekbones, bridge of your nose, and cupid\'s bow for a dazzling glow.'**
  String get tutStep3Desc;

  /// Botón que abre el espejo con el maquillaje del look.
  ///
  /// In en, this message translates to:
  /// **'Try on in AR'**
  String get tryOnAr;

  /// Título de la pantalla de creación de looks con IA (admin).
  ///
  /// In en, this message translates to:
  /// **'AI Studio'**
  String get studioTitle;

  /// Opción del menú de admin del catálogo.
  ///
  /// In en, this message translates to:
  /// **'Create with AI (Studio)'**
  String get studioMenuStudio;

  /// Opción del menú de admin del catálogo.
  ///
  /// In en, this message translates to:
  /// **'Edit tutorial steps'**
  String get studioMenuSteps;

  /// Ayuda del campo de texto del Studio.
  ///
  /// In en, this message translates to:
  /// **'Describe the look (e.g. gothic lips and orange blush)'**
  String get studioPromptHint;

  /// Botón que pide 3 variantes a la IA.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get studioGenerate;

  /// Ayuda del campo de remix.
  ///
  /// In en, this message translates to:
  /// **'Tweak (e.g. more natural, warmer tones)'**
  String get studioRemixHint;

  /// Botón que modifica la variante elegida con IA.
  ///
  /// In en, this message translates to:
  /// **'Remix'**
  String get studioRemix;

  /// Nota sobre la vista previa del Studio.
  ///
  /// In en, this message translates to:
  /// **'Studio: pick a variant and adjust it before publishing.'**
  String get studioNote;

  /// Estado inicial del Studio.
  ///
  /// In en, this message translates to:
  /// **'Write a request and tap Generate.'**
  String get studioEmpty;

  /// Botón del Studio.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get studioSaveDraft;

  /// Botón del Studio.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get studioPublish;

  /// Lista de borradores del Studio.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get studioDrafts;

  /// Lista de borradores vacía.
  ///
  /// In en, this message translates to:
  /// **'No drafts.'**
  String get studioNoDrafts;

  /// Acción sobre un borrador.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get studioDeleteDraft;

  /// Confirmación.
  ///
  /// In en, this message translates to:
  /// **'Draft saved.'**
  String get studioSaved;

  /// Confirmación.
  ///
  /// In en, this message translates to:
  /// **'Look published to the catalog.'**
  String get studioPublished;

  /// Error al guardar o publicar.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check your connection.'**
  String get studioSaveError;

  /// Campo del nombre del look.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get studioName;

  /// Campo de categoría del look.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get studioCategory;

  /// Campo de imagen del catálogo.
  ///
  /// In en, this message translates to:
  /// **'Image URL (optional)'**
  String get studioImageUrl;

  /// Botón de diálogo.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get studioCancel;

  /// Botón de diálogo.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get studioAccept;

  /// Quitar una capa de la receta.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get studioRemove;

  /// Campo de color HEX.
  ///
  /// In en, this message translates to:
  /// **'Color (#RRGGBB)'**
  String get studioColorHex;

  /// Acabado del labial.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get studioFinish;

  /// Capa editable.
  ///
  /// In en, this message translates to:
  /// **'Lipstick'**
  String get studioLayerLips;

  /// Capa editable.
  ///
  /// In en, this message translates to:
  /// **'Lip liner'**
  String get studioLayerLipLiner;

  /// Capa editable.
  ///
  /// In en, this message translates to:
  /// **'Blush'**
  String get studioLayerCheeks;

  /// Capa editable.
  ///
  /// In en, this message translates to:
  /// **'Foundation'**
  String get studioLayerFoundation;

  /// Capa editable.
  ///
  /// In en, this message translates to:
  /// **'Contour'**
  String get studioLayerContour;

  /// Capa editable.
  ///
  /// In en, this message translates to:
  /// **'Highlighter'**
  String get studioLayerHighlight;

  /// Capa editable.
  ///
  /// In en, this message translates to:
  /// **'Eyeliner'**
  String get studioLayerEyeLiner;

  /// Capa editable.
  ///
  /// In en, this message translates to:
  /// **'Lashes'**
  String get studioLayerLashes;

  /// Capa editable (sombra de ojos número index).
  ///
  /// In en, this message translates to:
  /// **'Shadow {index}'**
  String studioLayerShadow(int index);

  /// Aviso de respaldo.
  ///
  /// In en, this message translates to:
  /// **'The AI returned no valid variants: showing the closest preset.'**
  String get studioFallback;

  /// Error de generación.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use the Studio.'**
  String get studioErrorAuth;

  /// Error de generación.
  ///
  /// In en, this message translates to:
  /// **'Only admins can generate looks.'**
  String get studioErrorAdmin;

  /// Error de generación.
  ///
  /// In en, this message translates to:
  /// **'The request must be 1 to 300 characters.'**
  String get studioErrorInput;

  /// Error de generación.
  ///
  /// In en, this message translates to:
  /// **'Today\'s quota is used up. Try tomorrow.'**
  String get studioErrorQuota;

  /// Error de generación.
  ///
  /// In en, this message translates to:
  /// **'The generator isn\'t responding. Try again later.'**
  String get studioErrorUnavailable;

  /// Error de generación.
  ///
  /// In en, this message translates to:
  /// **'The app failed verification (App Check).'**
  String get studioErrorAppCheck;

  /// Error de generación.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate.'**
  String get studioErrorUnknown;

  /// No description provided for @studioFromPhoto.
  ///
  /// In en, this message translates to:
  /// **'From photo'**
  String get studioFromPhoto;

  /// No description provided for @studioPalette.
  ///
  /// In en, this message translates to:
  /// **'Product palette'**
  String get studioPalette;

  /// No description provided for @studioPhotoNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Reference photo'**
  String get studioPhotoNoticeTitle;

  /// No description provided for @studioPhotoNotice.
  ///
  /// In en, this message translates to:
  /// **'The photo is analyzed on this phone: it is not uploaded or stored. Use your own photos or ones you have permission to use from the person shown.'**
  String get studioPhotoNotice;

  /// No description provided for @studioContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get studioContinue;

  /// No description provided for @studioPhotoNoFace.
  ///
  /// In en, this message translates to:
  /// **'No face was found in the photo.'**
  String get studioPhotoNoFace;

  /// No description provided for @studioPhotoSmall.
  ///
  /// In en, this message translates to:
  /// **'The face is too small: use a closer photo.'**
  String get studioPhotoSmall;

  /// No description provided for @studioPhotoProfile.
  ///
  /// In en, this message translates to:
  /// **'The face is turned: use a front-facing photo.'**
  String get studioPhotoProfile;

  /// No description provided for @studioPhotoBad.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be analyzed.'**
  String get studioPhotoBad;

  /// No description provided for @studioPhotoFaithful.
  ///
  /// In en, this message translates to:
  /// **'Photo · faithful'**
  String get studioPhotoFaithful;

  /// No description provided for @studioPhotoBolder.
  ///
  /// In en, this message translates to:
  /// **'Photo · bolder'**
  String get studioPhotoBolder;

  /// No description provided for @studioPhotoSubtler.
  ///
  /// In en, this message translates to:
  /// **'Photo · subtler'**
  String get studioPhotoSubtler;

  /// No description provided for @studioPhotoRough.
  ///
  /// In en, this message translates to:
  /// **'Approximate match: check the colors in the preview.'**
  String get studioPhotoRough;

  /// No description provided for @studioRegionConfidence.
  ///
  /// In en, this message translates to:
  /// **'{layer}: {percent}%'**
  String studioRegionConfidence(String layer, int percent);

  /// No description provided for @studioPaletteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No colors were found in the photo.'**
  String get studioPaletteEmpty;

  /// No description provided for @studioPalettePickLayer.
  ///
  /// In en, this message translates to:
  /// **'Where does this color go?'**
  String get studioPalettePickLayer;

  /// No description provided for @studioNewShadow.
  ///
  /// In en, this message translates to:
  /// **'New shadow'**
  String get studioNewShadow;

  /// No description provided for @studioQaTitle.
  ///
  /// In en, this message translates to:
  /// **'Quality check'**
  String get studioQaTitle;

  /// No description provided for @studioQaVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get studioQaVisibility;

  /// No description provided for @studioQaClipping.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get studioQaClipping;

  /// No description provided for @studioQaConsistency.
  ///
  /// In en, this message translates to:
  /// **'Skin tones'**
  String get studioQaConsistency;

  /// No description provided for @studioQaCoverage.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get studioQaCoverage;

  /// No description provided for @studioQaCost.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get studioQaCost;

  /// No description provided for @studioQaOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get studioQaOk;

  /// No description provided for @studioQaCostOk.
  ///
  /// In en, this message translates to:
  /// **'Within what was measured on the reference phone'**
  String get studioQaCostOk;

  /// No description provided for @studioQaInvisible.
  ///
  /// In en, this message translates to:
  /// **'{layer}: not visible on any skin tone'**
  String studioQaInvisible(String layer);

  /// No description provided for @studioQaSubtle.
  ///
  /// In en, this message translates to:
  /// **'{layer}: barely visible'**
  String studioQaSubtle(String layer);

  /// No description provided for @studioQaWashedOut.
  ///
  /// In en, this message translates to:
  /// **'{layer}: very saturated, washes out in light'**
  String studioQaWashedOut(String layer);

  /// No description provided for @studioQaChalky.
  ///
  /// In en, this message translates to:
  /// **'{layer}: looks chalky on deep skin'**
  String studioQaChalky(String layer);

  /// No description provided for @studioQaAshy.
  ///
  /// In en, this message translates to:
  /// **'{layer}: looks ashy on deep skin'**
  String studioQaAshy(String layer);

  /// No description provided for @studioQaFades.
  ///
  /// In en, this message translates to:
  /// **'{layer}: not visible on some skin tones'**
  String studioQaFades(String layer);

  /// No description provided for @studioQaExtremeLiner.
  ///
  /// In en, this message translates to:
  /// **'Liner and wing at maximum'**
  String get studioQaExtremeLiner;

  /// No description provided for @studioQaMaskFoundation.
  ///
  /// In en, this message translates to:
  /// **'Very heavy foundation (mask effect)'**
  String get studioQaMaskFoundation;

  /// No description provided for @studioQaHeavyBlush.
  ///
  /// In en, this message translates to:
  /// **'Very large, intense blush'**
  String get studioQaHeavyBlush;

  /// No description provided for @studioQaEffects.
  ///
  /// In en, this message translates to:
  /// **'3 effects at once: not measured on the reference phone'**
  String get studioQaEffects;

  /// No description provided for @studioQaBlocked.
  ///
  /// In en, this message translates to:
  /// **'Fix the items in red to publish.'**
  String get studioQaBlocked;

  /// No description provided for @studioLayerIris.
  ///
  /// In en, this message translates to:
  /// **'Iris (colored lenses)'**
  String get studioLayerIris;

  /// No description provided for @myAiLooksTitle.
  ///
  /// In en, this message translates to:
  /// **'My AI looks'**
  String get myAiLooksTitle;

  /// No description provided for @myAiLooksPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the look (e.g. red lips and graphic liner)'**
  String get myAiLooksPromptHint;

  /// No description provided for @myAiLooksDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} per day'**
  String myAiLooksDailyLimit(int count);

  /// No description provided for @myAiLooksGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get myAiLooksGenerate;

  /// No description provided for @myAiLooksVariants.
  ///
  /// In en, this message translates to:
  /// **'Pick a variant'**
  String get myAiLooksVariants;

  /// No description provided for @myAiLooksSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get myAiLooksSuggestion;

  /// No description provided for @myAiLooksTry.
  ///
  /// In en, this message translates to:
  /// **'Try on'**
  String get myAiLooksTry;

  /// No description provided for @myAiLooksSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get myAiLooksSave;

  /// No description provided for @myAiLooksSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to your looks'**
  String get myAiLooksSaved;

  /// No description provided for @myAiLooksSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get myAiLooksSavedTitle;

  /// No description provided for @myAiLooksEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t saved any AI looks yet.'**
  String get myAiLooksEmpty;

  /// No description provided for @myAiLooksDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get myAiLooksDelete;

  /// No description provided for @myAiLooksDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String myAiLooksDeleteConfirm(String name);

  /// No description provided for @myAiLooksErrorQuota.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s limit of {count} looks. Try again tomorrow.'**
  String myAiLooksErrorQuota(int count);

  /// No description provided for @myAiLooksErrorFull.
  ///
  /// In en, this message translates to:
  /// **'You already have {count} saved looks. Delete one to save another.'**
  String myAiLooksErrorFull(int count);

  /// No description provided for @myAiLooksErrorLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create looks.'**
  String get myAiLooksErrorLogin;

  /// No description provided for @myAiLooksErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete. Please try again.'**
  String get myAiLooksErrorGeneric;

  /// No description provided for @myAiLooksFallback.
  ///
  /// In en, this message translates to:
  /// **'The AI didn\'t respond: here\'s a similar look.'**
  String get myAiLooksFallback;

  /// No description provided for @myAiLooksInvalidPrompt.
  ///
  /// In en, this message translates to:
  /// **'Write between 1 and {max} characters.'**
  String myAiLooksInvalidPrompt(int max);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
