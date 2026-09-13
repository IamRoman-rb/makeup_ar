// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AR Makeup App';

  @override
  String get discoverLooks => 'Discover Looks';

  @override
  String get searchHint => 'Search for filters or brands...';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryLips => 'Lips';

  @override
  String get categoryEyes => 'Eyes';

  @override
  String get categoryComplexion => 'Complexion';

  @override
  String noLooksFound(Object category) {
    return 'No looks found in $category category.';
  }

  @override
  String noResultsFor(Object category, Object query) {
    return 'No results for \"$query\" in $category.';
  }

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginSubtitle => 'Please enter your details to sign in.';

  @override
  String get emailOrUser => 'Email or Username';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get logIn => 'LOG IN';

  @override
  String get noAccount => 'Don\'t have an account? ';

  @override
  String get signUp => 'Sign Up';

  @override
  String get createProfile => 'Create Your Profile';

  @override
  String get joinSubtitle =>
      'Join Lumière Beauty for a curated cosmetic experience.';

  @override
  String get fullName => 'Full Name';

  @override
  String get email => 'Email Address';

  @override
  String get age => 'Age';

  @override
  String get dob => 'Date of Birth';

  @override
  String get skinType => 'Skin Type';

  @override
  String get skinTone => 'Skin Tone';

  @override
  String get personalTastes => 'Personal Tastes';

  @override
  String get createAccount => 'Create Account';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get updateProfile => 'Update Profile';

  @override
  String get skinTypeLabel => 'SKIN TYPE';

  @override
  String get toneLabel => 'TONE';

  @override
  String get savedLooks => 'Saved\nLooks';

  @override
  String get tutorials => 'Tutorials';

  @override
  String get favorites => 'Favorites';

  @override
  String get mySavedLooks => 'My Saved Looks';

  @override
  String get viewAll => 'View All >';

  @override
  String get settings => 'Settings';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get appLanguage => 'App Language';

  @override
  String get logOut => 'Log Out';

  @override
  String get security => 'Security';

  @override
  String get changePassword => 'Change Password';

  @override
  String get changePasswordDesc => 'We will send a reset link to your email.';

  @override
  String get sendLink => 'Send Link';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotif => 'Push Notifications';

  @override
  String get pushNotifDesc => 'Alerts for new looks and features.';

  @override
  String get emailNotif => 'Email Newsletters';

  @override
  String get emailNotifDesc => 'Weekly beauty tips and inspiration.';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountDesc =>
      'Once you delete your account, there is no going back. Please be certain.';

  @override
  String get deleteMyAccountBtn => 'Delete My Account';

  @override
  String get selectLanguageTitle => 'Language / Idioma';

  @override
  String get selectLanguageDesc =>
      'Select your preferred language for the application.';

  @override
  String get saved => 'Saved';

  @override
  String get save => 'Save';

  @override
  String get tutorial => 'Tutorial';

  @override
  String get effectOn => 'Effect On';

  @override
  String get effectOff => 'Effect Off';

  @override
  String get profileUpdated => 'Profile updated successfully!';

  @override
  String get errorSaving => 'Error saving:';

  @override
  String get loginFirst => 'Please log in first.';

  @override
  String get noSavedLooks =>
      'You haven\'t saved any looks yet.\nExplore the catalog to find your favorites!';

  @override
  String get unknownLook => 'Unknown Look';

  @override
  String get explore => 'Explore';

  @override
  String get profile => 'Profile';

  @override
  String get fillRequiredFields => 'Please fill all required fields';

  @override
  String get registrationError => 'Registration error';

  @override
  String get stepByStepTitle => 'Step-by-Step Guide';

  @override
  String get stepLabel => 'STEP';

  @override
  String get backBtn => 'Back';

  @override
  String get finishBtn => 'Finish';

  @override
  String get nextStepBtn => 'Next Step';

  @override
  String get tutStep1Title => 'Luminous Foundation';

  @override
  String get tutStep1Desc =>
      'Apply a few drops of foundation to the center of your face. Blend outwards using a brush or damp sponge for a natural, radiant, and even finish.';

  @override
  String get tutStep2Title => 'Velvet Liquid Blush';

  @override
  String get tutStep2Desc =>
      'Place three small dots of liquid blush on your high cheekbones. Blend quickly with light taps towards your temples for a spectacular lifting effect.';

  @override
  String get tutStep3Title => 'Gold Highlighter';

  @override
  String get tutStep3Desc =>
      'Gently apply the highlighter to the high points of your face: tops of your cheekbones, bridge of your nose, and cupid\'s bow for a dazzling glow.';
}
