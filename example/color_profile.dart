// Ported from charmbracelet/bubbletea examples/color-profile
import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program().run(ColorProfileModel());
}

final class ColorProfileModel extends TeaModel {
  ColorProfileModel({
    this.profile = ColorProfile.trueColor,
    this.bgRgb = 0x000000,
  });
  final ColorProfile profile;
  final int bgRgb;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is ColorProfileMsg) {
      return (ColorProfileModel(profile: msg.profile, bgRgb: bgRgb), null);
    }
    if (msg is BackgroundColorMsg) {
      return (ColorProfileModel(profile: profile, bgRgb: msg.rgb), null);
    }
    if (msg is KeyMsg) {
      if (msg.key == 'q' || msg.key == 'ctrl+c') return (this, () => quit());
      // Cycle through profiles manually for demo
      switch (msg.key) {
        case 'n':
          return (
            ColorProfileModel(profile: ColorProfile.noColor, bgRgb: bgRgb),
            null,
          );
        case 'a':
          return (
            ColorProfileModel(profile: ColorProfile.ansi, bgRgb: bgRgb),
            null,
          );
        case '2':
          return (
            ColorProfileModel(profile: ColorProfile.ansi256, bgRgb: bgRgb),
            null,
          );
        case 't':
          return (
            ColorProfileModel(profile: ColorProfile.trueColor, bgRgb: bgRgb),
            null,
          );
      }
    }
    return (this, null);
  }

  @override
  View view() {
    final s = Style(profile: profile);
    final b = StringBuffer();
    b.writeln(const Style().bold().render('Color Profile Demo'));
    b.writeln();
    b.writeln('Current profile: ${profile.name}');
    b.writeln();
    b.writeln(s.foregroundColor256(196).render('  256-color Red (index 196)'));
    b.writeln(
      s.foregroundColorRgb(107, 80, 255).render('  RGB Purple (#6b50ff)'),
    );
    b.writeln(
      s.bold().foregroundColor256(46).render('  Bold Green (index 46)'),
    );
    b.writeln(
      s
          .foregroundColor256(214)
          .backgroundColorRgb(30, 30, 30)
          .render('  Orange on dark'),
    );
    b.writeln();
    b.writeln('n: noColor  a: ansi  2: ansi256  t: trueColor  q: quit');
    return newView(b.toString());
  }
}
