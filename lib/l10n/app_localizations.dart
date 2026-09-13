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
