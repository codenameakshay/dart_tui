import '../../gmail/models.dart';
import '../../util/theme.dart';
import '../../util/width.dart';

class RowBound {
  RowBound(this.yStart, this.yEnd, this.index);
  final int yStart;
  final int yEnd;
  final int index;
}

/// Renders the message-list pane body (no border — caller frames it).
///
/// Returns [height] lines each of [width] cells. Populates [outBounds] with the
/// vertical row extents of each visible item (for mouse hit-testing), in
/// coordinates relative to this pane's TOP-LEFT (0,0).
List<String> renderMessageList({
  required List<MessageSummary> items,
  required int cursor,
  required int width,
  required int height,
  required List<RowBound> outBounds,
  bool loading = false,
  String loadingFrame = '⠋',
}) {
  outBounds.clear();
  final lines = <String>[];

  if (loading && items.isEmpty) {
    final mid = (height ~/ 2) - 1;
    for (var i = 0; i < height; i++) {
      if (i == mid) {
        final msg =
            '  ${sAccent.render(loadingFrame)}  ${sMuted.render('Loading messages…')}';
        lines.add(fitRight(msg, width));
      } else {
        lines.add('');
      }
    }
    return lines;
  }

  if (items.isEmpty) {
    final mid = (height ~/ 2) - 1;
    for (var i = 0; i < height; i++) {
      lines.add(
          i == mid ? fitRight('  ${sDim.render('(no messages)')}', width) : '');
    }
    return lines;
  }

  // Columns: [dot][space][sender][space][subject][space][date]
  // overhead = 1 (dot) + 3 (gutters) = 4 cells. Date fixed at 8.
  const overhead = 4;
  const wDate = 8;
  final budget = (width - overhead - wDate).clamp(10, 9999);
  final wSender = (budget * 0.40).round().clamp(8, 22);
  final wSubject = (budget - wSender).clamp(6, 9999);

  final rows = items.take(height).toList();
  for (var i = 0; i < rows.length; i++) {
    final m = rows[i];
    final isSel = i == cursor;
    final isUnread = m.labels.contains('UNREAD');
    final dot = isUnread ? sRowSenderUnread.render(iDot) : sDim.render(' ');
    final sender = _senderName(m.from);
    final date = _shortDate(m.date);

    final senderCell = fitRight(sender, wSender);
    final subjectCell = fitRight(m.subject, wSubject);
    final dateCell = fitLeft(date, wDate);

    final senderStyle =
        isSel ? sRowSelected : (isUnread ? sRowSenderUnread : sRowSender);
    final subjectStyle =
        isSel ? sRowSelected : (isUnread ? sRowSubjectUnread : sRowSubject);
    final dateStyle = isSel ? sRowSelected : sRowDate;

    if (isSel) {
      final raw =
          '$dot ${fitRight(sender, wSender)} ${fitRight(m.subject, wSubject)} ${fitLeft(date, wDate)}';
      lines.add(sRowSelected.render(fitRight(raw, width)));
    } else {
      final line =
          '$dot ${senderStyle.render(senderCell)} ${subjectStyle.render(subjectCell)} ${dateStyle.render(dateCell)}';
      lines.add(fitRight(line, width));
    }
    outBounds.add(RowBound(i, i, i));
  }
  while (lines.length < height) {
    lines.add('');
  }
  return lines;
}

String _senderName(String raw) {
  final lt = raw.indexOf('<');
  if (lt > 0) {
    final name = raw.substring(0, lt).trim().replaceAll('"', '');
    if (name.isNotEmpty) return name;
  }
  return raw;
}

/// RFC 2822-ish dates from gws: "Tue, 21 Apr 2026 14:48:58 +0000". Render as
/// "HH:MM" if same calendar day (local), else "MMM dd".
String _shortDate(String raw) {
  if (raw.isEmpty) return '';
  DateTime? dt;
  try {
    dt = _parseRfc2822(raw);
  } catch (_) {
    return raw.length > 8 ? raw.substring(0, 8) : raw;
  }
  if (dt == null) return raw;
  final local = dt.toLocal();
  final now = DateTime.now();
  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (sameDay) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day.toString().padLeft(2, ' ')}';
}

DateTime? _parseRfc2822(String s) {
  // Example: "Tue, 21 Apr 2026 14:48:58 +0000"
  final parts = s.split(RegExp(r'\s+'));
  if (parts.length < 5) return null;
  var i = 0;
  if (parts[0].endsWith(',')) i = 1; // skip weekday
  if (parts.length < i + 4) return null;
  final day = int.tryParse(parts[i]);
  final month = _month(parts[i + 1]);
  final year = int.tryParse(parts[i + 2]);
  final time = parts[i + 3].split(':');
  if (day == null || month == null || year == null || time.length < 2) {
    return null;
  }
  final hour = int.tryParse(time[0]) ?? 0;
  final min = int.tryParse(time[1]) ?? 0;
  final sec = time.length > 2 ? int.tryParse(time[2]) ?? 0 : 0;
  // UTC interpretation; tz offset parsing skipped for the short label use case.
  return DateTime.utc(year, month, day, hour, min, sec);
}

int? _month(String s) => switch (s) {
      'Jan' => 1,
      'Feb' => 2,
      'Mar' => 3,
      'Apr' => 4,
      'May' => 5,
      'Jun' => 6,
      'Jul' => 7,
      'Aug' => 8,
      'Sep' => 9,
      'Oct' => 10,
      'Nov' => 11,
      'Dec' => 12,
      _ => null,
    };
