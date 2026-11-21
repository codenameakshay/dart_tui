// Run: dart_tui dev example/hot_reload.dart
// A counter to try hot reload on: press + a few times, then change `accent`
// or `boxed` below and save. The view redraws and the count stays.

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program().run(CounterModel());
}

RgbColor get accent => const RgbColor(137, 180, 250);
bool get boxed => false;

final class CounterModel extends Model {
  CounterModel({this.count = 0});

  final int count;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case '+' || 'up':
          return (CounterModel(count: count + 1), null);
        case '-' || 'down':
          return (CounterModel(count: count - 1), null);
        case 'q' || 'ctrl+c':
          return (this, () => quit());
      }
    }
    return (this, null);
  }

  @override
  View view() {
    final title = Style(foregroundRgb: accent, isBold: true).render('Count');
    final value = Style(foregroundRgb: accent).render('$count');
    const help = Style(foregroundRgb: RgbColor(108, 112, 134));
    final body = boxed ? '$title\n\n   $value' : '$title  $value';
    final card = boxed
        ? Style(
            border: Border.rounded,
            borderForeground: accent,
            padding: const EdgeInsets.all(1),
          ).render(body)
        : body;
    return newView('$card\n\n${help.render('+/- change · q quit')}');
  }
}
