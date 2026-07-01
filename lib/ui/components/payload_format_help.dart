import '../../l10n/generated/app_localizations.dart';
import '../../models/payload_format.dart';

/// One-line, localized explanation of what a given [PayloadFormat] produces.
/// Rendered under the data-format selector so the chosen wire shape is obvious.
String payloadFormatDescription(AppLocalizations l10n, String format) {
  switch (PayloadFormat.normalize(format)) {
    case PayloadFormat.simpleKv:
      return l10n.formatSimpleKvDesc;
    case PayloadFormat.array:
      return l10n.formatTbArrayDesc;
    case PayloadFormat.tieNiu:
      return l10n.formatTieNiuDesc;
    case PayloadFormat.tieNiuEmpty:
      return l10n.formatTieNiuEmptyDesc;
    case PayloadFormat.timestamped:
    default:
      return l10n.formatTbTimestampDesc;
  }
}
