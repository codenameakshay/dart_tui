import 'package:dart_tui/dart_tui.dart';

import '../../gmail/models.dart';
import '../../util/theme.dart';
import '../../util/width.dart';

/// Renders the right-pane body (no border — caller frames it).
/// Returns [height] lines of [width] cells.
List<String> renderMessageView({
  required int width,
  required int height,
  required bool loading,
  required String? error,
  required Message? message,
  required ViewportModel viewport,
  String loadingFrame = '⠋',
  double? progress,
}) {
  final lines = <String>[];

  if (loading) {
    final mid = (height ~/ 2) - 1;
    for (var i = 0; i < height; i++) {
      if (i == mid) {
        final msg =
            '  ${sAccent.render(loadingFrame)}  ${sMuted.render('Loading message…')}';
        lines.add(fitRight(msg, width));
      } else {
        lines.add('');
      }
    }
    return lines;
  }
  if (error != null) {
    final mid = (height ~/ 2) - 1;
    for (var i = 0; i < height; i++) {
      if (i == mid) {
        lines.add(fitRight(
            '  ${sError.render('$iError ')} ${sError.render(error)}', width));
      } else if (i == mid + 2) {
        lines.add(fitRight(
            '  ${sMuted.render('Press')} ${sAccent.render('r')} ${sMuted.render('to retry.')}',
            width));
      } else {
        lines.add('');
      }
    }
    return lines;
  }
  if (message == null) {
    final mid = (height ~/ 2) - 1;
    for (var i = 0; i < height; i++) {
      lines.add(i == mid
          ? fitRight('  ${sDim.render('Select a message to read.')}', width)
          : '');
    }
    return lines;
  }

  // Header block.
  lines.add(fitRight('  ${sHeader.render(message.subject)}', width));
  lines.add('');
  lines.add(fitRight(_kv('From', message.from.display, width), width));
  lines.add(fitRight(
      _kv('To', message.to.map((e) => e.display).join(', '), width), width));
  if (message.cc.isNotEmpty) {
    lines.add(fitRight(
        _kv('Cc', message.cc.map((e) => e.display).join(', '), width), width));
  }
  lines.add(fitRight(_kv('Date', message.date, width), width));
  lines.add(fitRight(sDim.render('  ${'─' * (width - 4)}'), width));

  // Body via viewport.
  final used = lines.length;
  final bodyHeight = (height - used).clamp(0, height);
  if (bodyHeight > 0) {
    final body = viewport.view().content.split('\n');
    for (var i = 0; i < bodyHeight; i++) {
      if (i < body.length) {
        lines.add(fitRight('  ${body[i]}', width));
      } else {
        lines.add('');
      }
    }
  }
  while (lines.length < height) {
    lines.add('');
  }
  return lines.take(height).toList();
}

String _kv(String k, String v, int width) {
  final key = sMuted.render('  ${k.padRight(4)} ');
  final remaining = width - 7;
  final val = sText.render(fitRight(v, remaining.clamp(1, 9999)));
  return key + val;
}
