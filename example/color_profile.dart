// Ported from charmbracelet/bubbletea examples/color-profile
//
// The Program detects the colour profile from the environment, and every
// Style follows it. Try:
//   COLORTERM=truecolor dart run example/color_profile.dart
//   env -u COLORTERM TERM=xterm-256color dart run example/color_profile.dart
//   NO_COLOR=1 dart run example/color_profile.dart
import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program().run(ColorProfileModel());
}

final class ColorProfileModel extends Model {
  ColorProfileModel({this.detected, this.pinned, this.background});

  /// The profile the Program detected.
  final ColorProfile? detected;

  /// A profile picked with a key, or null to follow detection.
  final ColorProfile? pinned;

  /// The terminal background, once the terminal answers the OSC 11 query.
  final int? background;

  ColorProfileModel _copy({
    ColorProfile? detected,
    ColorProfile? pinned,
    int? background,
  }) =>
      ColorProfileModel(
        detected: detected ?? this.detected,
        pinned: pinned ?? this.pinned,
        background: background ?? this.background,
      );

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is ColorProfileMsg) return (_copy(detected: msg.profile), null);
    if (msg is BackgroundColorMsg) return (_copy(background: msg.rgb), null);
    if (msg is KeyMsg) {
      final picked = switch (msg.key) {
        'n' => ColorProfile.noColor,
        'a' => ColorProfile.ansi,
        '2' => ColorProfile.ansi256,
        't' => ColorProfile.trueColor,
        _ => null,
      };
      if (picked != null) return (_copy(pinned: picked), null);
      if (msg.key == 'q' || msg.key == 'ctrl+c' || msg.key == 'enter') {
        return (this, () => quit());
      }
    }
    return (this, null);
  }

  @override
  View view() {
    // No explicit profile: styles use Style.defaultProfile, which the
    // Program set from detection. A picked key pins one instead.
    final s = Style(profile: pinned);
    final bg = background;
    final b = StringBuffer()
      ..writeln(const Style().bold().render('Color Profile Demo'))
      ..writeln('detected: ${detected?.name ?? '…'}'
          '${pinned == null ? '' : '   showing: ${pinned!.name}'}')
      ..writeln('background: ${bg == null ? 'unknown' : '#'
          '${bg.toRadixString(16).padLeft(6, '0')}'
          ' (${isDarkRgb(bg) ? 'dark' : 'light'})'}')
      ..writeln(
          s.foregroundColorRgb(107, 80, 255).render('  RGB purple #6b50ff'))
      ..writeln(s.foregroundColor256(214).render('  256-colour orange 214'))
      ..writeln(
          s.bold().foregroundColorRgb(80, 200, 120).render('  Bold green'))
      ..writeln(s.underline().render('  Underline stays without colour'))
      ..writeln(
        s
            .copyWith(
              adaptiveForeground: const AdaptiveColor(
                light: RgbColor(30, 30, 160),
                dark: RgbColor(255, 220, 120),
              ),
            )
            .render('  Adaptive: navy on light, gold on dark'),
      )
      ..write('n/a/2/t: pin a profile  q: quit');
    return newView(b.toString());
  }
}
