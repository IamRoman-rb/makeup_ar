import 'package:ar_makeup_app/l10n/app_localizations.dart';

import '../domain/coach.dart';

/// Nombre de una zona para mostrar y decir.
String coachZoneName(AppLocalizations l10n, CoachZone zone) => switch (zone) {
      CoachZone.lips => l10n.coachZoneLips,
      CoachZone.lipLiner => l10n.coachZoneLipLiner,
      CoachZone.cheeks => l10n.coachZoneCheeks,
      CoachZone.eyeLiner => l10n.coachZoneEyeLiner,
      CoachZone.shadowLid => l10n.coachZoneShadowLid,
      CoachZone.shadowCrease => l10n.coachZoneShadowCrease,
      CoachZone.shadowOuterV => l10n.coachZoneShadowOuterV,
      CoachZone.shadowInnerCorner => l10n.coachZoneShadowInnerCorner,
      CoachZone.shadowBrowBone => l10n.coachZoneShadowBrowBone,
    };

/// La indicación completa (la misma en pantalla y en voz).
String coachPromptText(AppLocalizations l10n, CoachPrompt prompt) {
  if (prompt.done) return l10n.coachDone;
  final issue = prompt.issue;
  if (issue != null) {
    return switch (issue) {
      CoachIssue.lookAtCamera => l10n.coachLookAtCamera,
      CoachIssue.comeCloser => l10n.coachComeCloser,
      CoachIssue.moreLight => l10n.coachMoreLight,
    };
  }
  final zone = prompt.zone ?? CoachZone.lips;
  final name = coachZoneName(l10n, zone);
  return switch (prompt.verdict ?? CoachVerdict.ok) {
    CoachVerdict.ok => l10n.coachVerdictOk(name),
    CoachVerdict.tooLittle => zone == CoachZone.eyeLiner ? l10n.coachLinerMissing : l10n.coachTooLittle(name),
    CoachVerdict.tooMuch => l10n.coachTooMuch(name),
    CoachVerdict.tooDark => l10n.coachTooDark(name),
    CoachVerdict.tooLight => l10n.coachTooLight(name),
    CoachVerdict.otherTone => l10n.coachOtherTone(name),
    CoachVerdict.tooThin => l10n.coachLinerThin,
    CoachVerdict.tooThick => l10n.coachLinerThick,
    CoachVerdict.wingShort => l10n.coachWingShort,
    CoachVerdict.wingLong => l10n.coachWingLong,
    CoachVerdict.notVisible => l10n.coachNotVisible(name),
    CoachVerdict.tooFar => l10n.coachLinerTooFar,
  };
}
