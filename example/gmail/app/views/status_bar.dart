import '../../util/theme.dart';
import '../../util/width.dart';

/// Context-aware help/status bar.
///
/// [searching] takes full precedence: shows inline search input.
String renderStatusBar({
  required int width,
  required String query,
  required int totalShown,
  required int pageIndex,
  required bool loading,
  required String? error,
  required bool searching,
  required String searchInputView,
  required String spinnerFrame,
  required List<({String keys, String label})> hints,
}) {
  if (searching) {
    final prompt = sAccent.render(' $iSearch ');
    final hint = sStatusHint.render('   enter to search · esc to cancel');
    final left = prompt + searchInputView;
    final rightWidth = displayWidth(hint);
    final pad = (width - displayWidth(left) - rightWidth).clamp(0, 9999);
    return sStatusBar.render(left + ' ' * pad + hint);
  }

  final badge = error != null
      ? sError.render(' $iError ERROR ')
      : loading
          ? sAccent.render(' $spinnerFrame LOADING ')
          : sSuccess.render(' $iDot READY ');

  final ctx = sStatusHint
      .render('  $query  ·  $totalShown shown · page ${pageIndex + 1}  ');

  final hintsStr = StringBuffer();
  for (final h in hints) {
    hintsStr.write(sStatusKey.render(' ${h.keys} '));
    hintsStr.write(sStatusHint.render(' ${h.label} '));
  }

  final left = sStatusBar.render(' ') + badge + ctx;
  final right = hintsStr.toString() + sStatusBar.render(' ');
  final pad = (width - displayWidth(left) - displayWidth(right)).clamp(0, 9999);
  final padded = sStatusBar.render(' ' * pad);
  return left + padded + right;
}
