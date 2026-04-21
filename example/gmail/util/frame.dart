import 'theme.dart';
import 'width.dart';

/// Wraps [body] lines in a rounded box. Returns exactly [height] lines of
/// [width] cells. Body is clipped/padded as needed.
///
/// The body lines are expected to already have ANSI styling — [width]/[height]
/// measurements are cell-based via [displayWidth].
String frame({
  required List<String> body,
  required int width,
  required int height,
  String title = '',
  String? badge,
  bool focused = false,
}) {
  if (width < 4 || height < 2) {
    return List.filled(height, ' ' * width).join('\n');
  }
  final borderStyle = focused ? sBorderActive : sBorder;

  String horiz(String l, String r) {
    final inner = width - 2;
    if (title.isEmpty) {
      return borderStyle.render(l + '─' * inner + r);
    }
    final titleStyled =
        focused ? sBorderActive.render(' $title ') : sHeader.render(' $title ');
    final badgeStyled = badge == null ? '' : sDim.render(' $badge ');
    final used = displayWidth(titleStyled) + displayWidth(badgeStyled);
    final fill = (inner - used).clamp(0, inner);
    return borderStyle.render(l) +
        titleStyled +
        borderStyle.render('─' * fill) +
        badgeStyled +
        borderStyle.render(r);
  }

  final top = horiz('╭', '╮');
  final bottom = borderStyle.render('╰${'─' * (width - 2)}╯');

  final lines = <String>[top];
  final inner = width - 2;
  final bodyHeight = height - 2;
  for (var i = 0; i < bodyHeight; i++) {
    final raw = i < body.length ? body[i] : '';
    final fitted = fitRight(raw, inner);
    lines.add(borderStyle.render('│') + fitted + borderStyle.render('│'));
  }
  lines.add(bottom);
  return lines.join('\n');
}
