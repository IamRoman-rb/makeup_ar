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
  String get mirror => 'Mirror';

  @override
  String get testFilter => 'Test filter';

  @override
  String get testFilterNone => 'No filter';

  @override
  String get testFilterIntensity => 'Intensity';

  @override
  String get testFilterNote =>
      'New engine (beta): each look is applied in full with face tracking. The first time it takes a few seconds to load.';

  @override
  String get testFilterShowPoints => 'Show points';

  @override
  String get testFilterZoneAll => 'All';

  @override
  String get testFilterZoneLips => 'Lips';

  @override
  String get testFilterZoneEyes => 'Eyes';

  @override
  String get testFilterZoneCheeks => 'Cheeks';

  @override
  String get testFilterZoneSkin => 'Skin';

  @override
  String get testFilterUnavailable =>
      'Live makeup isn\'t available on this device. Showing the regular mirror.';

  @override
  String get testFilterCompare => 'Hold to compare';

  @override
  String get testFilterFinishMatte => 'Matte';

  @override
  String get testFilterFinishSatin => 'Satin';

  @override
  String get testFilterFinishGloss => 'Gloss';

  @override
  String get testFilterFinishShimmer => 'Shimmer';

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

  @override
  String get tryOnAr => 'Try on in AR';

  @override
  String get studioTitle => 'AI Studio';

  @override
  String get studioMenuStudio => 'Create with AI (Studio)';

  @override
  String get studioMenuSteps => 'Edit tutorial steps';

  @override
  String get studioPromptHint =>
      'Describe the look (e.g. gothic lips and orange blush)';

  @override
  String get studioGenerate => 'Generate';

  @override
  String get studioRemixHint => 'Tweak (e.g. more natural, warmer tones)';

  @override
  String get studioRemix => 'Remix';

  @override
  String get studioNote =>
      'Studio: pick a variant and adjust it before publishing.';

  @override
  String get studioEmpty => 'Write a request and tap Generate.';

  @override
  String get studioSaveDraft => 'Save draft';

  @override
  String get studioPublish => 'Publish';

  @override
  String get studioDrafts => 'Drafts';

  @override
  String get studioNoDrafts => 'No drafts.';

  @override
  String get studioDeleteDraft => 'Delete draft';

  @override
  String get studioSaved => 'Draft saved.';

  @override
  String get studioPublished => 'Look published to the catalog.';

  @override
  String get studioSaveError => 'Couldn\'t save. Check your connection.';

  @override
  String get studioName => 'Name';

  @override
  String get studioCategory => 'Category';

  @override
  String get studioImageUrl => 'Image URL (optional)';

  @override
  String get studioCancel => 'Cancel';

  @override
  String get studioAccept => 'OK';

  @override
  String get studioRemove => 'Remove';

  @override
  String get studioColorHex => 'Color (#RRGGBB)';

  @override
  String get studioFinish => 'Finish';

  @override
  String get studioLayerLips => 'Lipstick';

  @override
  String get studioLayerLipLiner => 'Lip liner';

  @override
  String get studioLayerCheeks => 'Blush';

  @override
  String get studioLayerFoundation => 'Foundation';

  @override
  String get studioLayerContour => 'Contour';

  @override
  String get studioLayerHighlight => 'Highlighter';

  @override
  String get studioLayerEyeLiner => 'Eyeliner';

  @override
  String get studioLayerLashes => 'Lashes';

  @override
  String studioLayerShadow(int index) {
    return 'Shadow $index';
  }

  @override
  String get studioFallback =>
      'The AI returned no valid variants: showing the closest preset.';

  @override
  String get studioErrorAuth => 'Sign in to use the Studio.';

  @override
  String get studioErrorAdmin => 'Only admins can generate looks.';

  @override
  String get studioErrorInput => 'The request must be 1 to 300 characters.';

  @override
  String get studioErrorQuota => 'Today\'s quota is used up. Try tomorrow.';

  @override
  String get studioErrorUnavailable =>
      'The generator isn\'t responding. Try again later.';

  @override
  String get studioErrorAppCheck => 'The app failed verification (App Check).';

  @override
  String get studioErrorUnknown => 'Couldn\'t generate.';

  @override
  String get studioFromPhoto => 'From photo';

  @override
  String get studioPalette => 'Product palette';

  @override
  String get studioPhotoNoticeTitle => 'Reference photo';

  @override
  String get studioPhotoNotice =>
      'The photo is analyzed on this phone: it is not uploaded or stored. Use your own photos or ones you have permission to use from the person shown.';

  @override
  String get studioContinue => 'Continue';

  @override
  String get studioPhotoNoFace => 'No face was found in the photo.';

  @override
  String get studioPhotoSmall => 'The face is too small: use a closer photo.';

  @override
  String get studioPhotoProfile =>
      'The face is turned: use a front-facing photo.';

  @override
  String get studioPhotoBad => 'The photo could not be analyzed.';

  @override
  String get studioPhotoFaithful => 'Photo · faithful';

  @override
  String get studioPhotoBolder => 'Photo · bolder';

  @override
  String get studioPhotoSubtler => 'Photo · subtler';

  @override
  String get studioPhotoRough =>
      'Approximate match: check the colors in the preview.';

  @override
  String studioRegionConfidence(String layer, int percent) {
    return '$layer: $percent%';
  }

  @override
  String get studioPaletteEmpty => 'No colors were found in the photo.';

  @override
  String get studioPalettePickLayer => 'Where does this color go?';

  @override
  String get studioNewShadow => 'New shadow';

  @override
  String get studioQaTitle => 'Quality check';

  @override
  String get studioQaVisibility => 'Visibility';

  @override
  String get studioQaClipping => 'Saturation';

  @override
  String get studioQaConsistency => 'Skin tones';

  @override
  String get studioQaCoverage => 'Coverage';

  @override
  String get studioQaCost => 'Performance';

  @override
  String get studioQaOk => 'OK';

  @override
  String get studioQaCostOk =>
      'Within what was measured on the reference phone';

  @override
  String studioQaInvisible(String layer) {
    return '$layer: not visible on any skin tone';
  }

  @override
  String studioQaSubtle(String layer) {
    return '$layer: barely visible';
  }

  @override
  String studioQaWashedOut(String layer) {
    return '$layer: very saturated, washes out in light';
  }

  @override
  String studioQaChalky(String layer) {
    return '$layer: looks chalky on deep skin';
  }

  @override
  String studioQaAshy(String layer) {
    return '$layer: looks ashy on deep skin';
  }

  @override
  String studioQaFades(String layer) {
    return '$layer: not visible on some skin tones';
  }

  @override
  String get studioQaExtremeLiner => 'Liner and wing at maximum';

  @override
  String get studioQaMaskFoundation => 'Very heavy foundation (mask effect)';

  @override
  String get studioQaHeavyBlush => 'Very large, intense blush';

  @override
  String get studioQaEffects =>
      '3 effects at once: not measured on the reference phone';

  @override
  String get studioQaBlocked => 'Fix the items in red to publish.';

  @override
  String get studioLayerIris => 'Iris (colored lenses)';

  @override
  String get myAiLooksTitle => 'My AI looks';

  @override
  String get myAiLooksPromptHint =>
      'Describe the look (e.g. red lips and graphic liner)';

  @override
  String myAiLooksDailyLimit(int count) {
    return 'Up to $count per day';
  }

  @override
  String get myAiLooksGenerate => 'Generate';

  @override
  String get myAiLooksVariants => 'Pick a variant';

  @override
  String get myAiLooksSuggestion => 'Suggestion';

  @override
  String get myAiLooksTry => 'Try on';

  @override
  String get myAiLooksSave => 'Save';

  @override
  String get myAiLooksSaved => 'Saved to your looks';

  @override
  String get myAiLooksSavedTitle => 'Saved';

  @override
  String get myAiLooksEmpty => 'You haven\'t saved any AI looks yet.';

  @override
  String get myAiLooksDelete => 'Delete';

  @override
  String myAiLooksDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String myAiLooksErrorQuota(int count) {
    return 'You\'ve reached today\'s limit of $count looks. Try again tomorrow.';
  }

  @override
  String myAiLooksErrorFull(int count) {
    return 'You already have $count saved looks. Delete one to save another.';
  }

  @override
  String get myAiLooksErrorLogin => 'Sign in to create looks.';

  @override
  String get myAiLooksErrorGeneric => 'Couldn\'t complete. Please try again.';

  @override
  String get myAiLooksFallback =>
      'The AI didn\'t respond: here\'s a similar look.';

  @override
  String myAiLooksInvalidPrompt(int max) {
    return 'Write between 1 and $max characters.';
  }

  @override
  String loginError(String details) {
    return 'Couldn\'t sign in: $details';
  }

  @override
  String errorWithDetails(String details) {
    return 'Error: $details';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get catalogCreateLookTooltip => 'Create look (admin)';

  @override
  String catalogLoadError(String details) {
    return 'Couldn\'t load the looks: $details';
  }

  @override
  String get filterEditorNewTitle => 'New look';

  @override
  String get filterEditorEditTitle => 'Edit look';

  @override
  String get filterEditorDefaultName => 'New look';

  @override
  String get filterEditorSaved => 'Look saved! 🚀';

  @override
  String filterEditorSaveError(String details) {
    return 'Couldn\'t save the look: $details';
  }

  @override
  String get filterEditorDeleteTitle => 'Delete look?';

  @override
  String get filterEditorDeleteBody => 'This can\'t be undone.';

  @override
  String get filterEditorDeleted => 'Look deleted 🗑️';

  @override
  String get filterEditorAdminOnly => 'Only an admin can create or edit looks.';

  @override
  String get filterEditorDeleteTooltip => 'Delete look';

  @override
  String get filterEditorName => 'Look name';

  @override
  String get filterEditorCategory => 'Category';

  @override
  String get filterEditorCoverUrl => 'Cover image URL (optional)';

  @override
  String get filterEditorVideoUrl => 'Tutorial video URL (optional, VIP only)';

  @override
  String get filterEditorSteps => 'Tutorial steps';

  @override
  String get filterEditorAddStep => 'Add step';

  @override
  String get filterEditorNoSteps => 'No steps yet.';

  @override
  String filterEditorStep(int number) {
    return 'Step $number';
  }

  @override
  String get filterEditorRemoveStep => 'Remove step';

  @override
  String get filterEditorStepTitle => 'Title';

  @override
  String get filterEditorStepImage => 'Image URL (optional)';

  @override
  String get filterEditorStepDescription => 'Description / instructions';

  @override
  String get stepsEmpty => 'There are no steps for this look yet.';

  @override
  String get tutorialNoVideoTitle => 'No video for this look';

  @override
  String get tutorialNoVideoBody =>
      'We haven\'t uploaded a video for this tutorial yet.';

  @override
  String get tutorialVipTitle => 'VIP tutorial';

  @override
  String get tutorialVipBody => 'Unlock the secrets of this look.';

  @override
  String get becomeVip => 'Go VIP';

  @override
  String passwordEmailSent(String email) {
    return 'Email sent to $email';
  }

  @override
  String get passwordEmailError => 'Couldn\'t send the email.';

  @override
  String get deleteAccountReauth =>
      'Log out and log back in before deleting your account.';

  @override
  String profileLoadError(String details) {
    return 'Couldn\'t load your profile: $details';
  }

  @override
  String get profileNoData => 'We couldn\'t find your profile data.';

  @override
  String profilePreferences(String list) {
    return 'Preferences: $list';
  }

  @override
  String get profileDefaultBio => 'Exploring elegant, minimalist aesthetics.';

  @override
  String get skinTypeCombined => 'Combination';

  @override
  String get skinTypeOily => 'Oily';

  @override
  String get skinTypeDry => 'Dry';

  @override
  String get skinTypeSensitive => 'Sensitive';

  @override
  String get skinToneLight => 'Light';

  @override
  String get skinToneMedium => 'Medium';

  @override
  String get skinToneTan => 'Tan';

  @override
  String get skinToneDeep => 'Deep';

  @override
  String get prefNatural => 'Natural';

  @override
  String get prefGlamour => 'Glamour';

  @override
  String get prefMinimalist => 'Minimalist';

  @override
  String get prefBold => 'Bold';

  @override
  String get prefSkincare => 'Skincare focus';

  @override
  String get vipUnavailable => 'VIP isn\'t available in this version.';

  @override
  String vipLoadError(String details) {
    return 'Couldn\'t load the VIP plans.\n$details';
  }

  @override
  String get vipPurchased =>
      'Done, you\'re VIP! 🎉 It activates in a few seconds.';

  @override
  String vipPurchaseError(String details) {
    return 'Couldn\'t complete the purchase: $details';
  }

  @override
  String get vipRestored =>
      'We found your VIP subscription! 🎉 It activates in a few seconds.';

  @override
  String get vipNothingToRestore => 'No purchases to restore.';

  @override
  String get vipRestore => 'Restore purchases';

  @override
  String get vipNoPlans => 'No VIP plan is set up yet.';

  @override
  String get vipHeadline => 'Unlock the videos of every tutorial';

  @override
  String get signupPhotoFailed =>
      'Your account was created, but we couldn\'t upload the photo. You can add it later from your profile.';
}
