import 'package:dart_tui/dart_tui.dart';

// ── Canvas compositing showcase ───────────────────────────────────────────────
//
// Demonstrates painting styled text blocks at arbitrary (x, y) positions with
// z-index layering.  Higher z-index content overwrites lower z-index content
// at overlapping cells.

void main() async {
  final model = CanvasShowcaseModel();
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(model);
}

final class CanvasShowcaseModel extends TeaModel {
  CanvasShowcaseModel({this.tick = 0});
  final int tick;

  @override
  Cmd? init() => every(const Duration(milliseconds: 80), TickMsg.new);

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is TickMsg) return (CanvasShowcaseModel(tick: tick + 1), null);
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, quit);
      }
    }
    return (this, null);
  }

  @override
  View view() {
    const w = 72;
    const h = 22;
    final canvas = Canvas(w, h);

    // ── Layer 0: background fill ──────────────────────────────────────────
    final bg = const Style(backgroundRgb: RgbColor(18, 18, 30))
        .withWidth(w)
        .withHeight(h);
    canvas.paint(0, 0, bg.render(''), zIndex: 0);

    // ── Layer 1: left panel (info) ────────────────────────────────────────
    final leftBorder = const Style(
      foregroundRgb: RgbColor(88, 91, 112), // Surface2
      border: Border.rounded,
    ).withWidth(30).withHeight(10).withPadding(const EdgeInsets.all(1));

    final leftContent = '''${gradientText('Canvas Compositing', [
          const RgbColor(203, 166, 247),
          const RgbColor(116, 199, 236),
        ])}

${const Style(foregroundRgb: RgbColor(166, 173, 200), isDim: true).render('Paint styled blocks at')}
${const Style(foregroundRgb: RgbColor(166, 173, 200), isDim: true).render('arbitrary (x, y) with')}
${const Style(foregroundRgb: RgbColor(166, 173, 200), isDim: true).render('z-index layering.')}

${const Style(foregroundRgb: RgbColor(205, 214, 244)).render('Higher z → draws on top')}''';

    canvas.paint(2, 2, leftBorder.render(leftContent), zIndex: 1);

    // ── Layer 2: right panel (z-index demo) ───────────────────────────────
    final rightPanel = const Style(
      foregroundRgb: RgbColor(137, 180, 250), // Blue
      border: Border.box,
    ).withWidth(28).withHeight(10).withPadding(const EdgeInsets.all(1));

    canvas.paint(38, 2, rightPanel.render(_zDemoContent()), zIndex: 1);

    // ── Layer 3: animated gradient banner ────────────────────────────────
    final bannerPhase = tick * 0.05;
    final r1 = (128 + (127 * _sin(bannerPhase))).round().clamp(0, 255);
    final g1 = (100 + (100 * _sin(bannerPhase + 2.0))).round().clamp(0, 255);
    final b1 = (200 + (55 * _sin(bannerPhase + 4.0))).round().clamp(0, 255);

    final bannerText = gradientText(
      '  ✦  dart_tui Canvas  ✦  ',
      [
        RgbColor(r1, g1, b1),
        const RgbColor(203, 166, 247),
        RgbColor((255 - r1).clamp(0, 255), g1, b1),
      ],
    );

    final bannerStyle = const Style(
      backgroundRgb: RgbColor(30, 30, 50),
      border: Border.thick,
      foregroundRgb: RgbColor(203, 166, 247),
    ).withWidth(34).withPadding(const EdgeInsets.all(1));

    canvas.paint(18, 14, bannerStyle.render(bannerText), zIndex: 2);

    // ── Layer 4: overlapping accent box (demonstrates z-index override) ───
    final accentBox = const Style(
      foregroundRgb: RgbColor(166, 227, 161), // Green
      border: Border.rounded,
    ).withWidth(14).withHeight(5).withPadding(const EdgeInsets.all(0));

    canvas.paint(
        14,
        12,
        accentBox.render(
            const Style(foregroundRgb: RgbColor(166, 227, 161), isDim: true)
                .render(' z:3 overlap')),
        zIndex: 3);

    // ── Status bar ────────────────────────────────────────────────────────
    final status = const Style(
      foregroundRgb: RgbColor(108, 112, 134), // Overlay0
      isDim: true,
    ).render('  q quit  •  layers: bg(z0)  panels(z1)  banner(z2)  accent(z3)');
    canvas.paint(0, h - 1, status, zIndex: 4);

    return newView(canvas.render());
  }

  String _zDemoContent() {
    const s = Style(foregroundRgb: RgbColor(137, 180, 250));
    const muted = Style(foregroundRgb: RgbColor(108, 112, 134), isDim: true);
    return '''${s.bold().render('Z-Index Layers')}

${muted.render('z=0')} ${const Style(foregroundRgb: RgbColor(88, 91, 112)).render('─ background fill')}
${muted.render('z=1')} ${const Style(foregroundRgb: RgbColor(205, 214, 244)).render('─ panels')}
${muted.render('z=2')} ${const Style(foregroundRgb: RgbColor(203, 166, 247)).render('─ banner')}
${muted.render('z=3')} ${const Style(foregroundRgb: RgbColor(166, 227, 161)).render('─ accent box')}''';
  }

  // Fast sine approximation for animation
  static double _sin(double x) {
    // Clamp to one period and approximate
    x = x % (2 * 3.14159);
    return x < 3.14159
        ? (4 * x * (3.14159 - x)) / (3.14159 * 3.14159)
        : -(4 * (x - 3.14159) * (2 * 3.14159 - x)) / (3.14159 * 3.14159);
  }
}
