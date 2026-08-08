import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('ProgressModel', () {
    test('fraction 0 shows empty bar', () {
      final p = ProgressModel(fraction: 0, width: 10);
      final content = p.view().content;
      expect(content, contains('0%'));
      // No filled cells
      expect(content, isNot(contains('█')));
    });

    test('fraction 1 shows full bar', () {
      final p = ProgressModel(fraction: 1, width: 10);
      final content = p.view().content;
      expect(content, contains('100%'));
      expect(content, contains('█' * 10));
    });

    test('fraction 0.5 fills half the bar', () {
      final p = ProgressModel(fraction: 0.5, width: 10);
      final content = p.view().content;
      expect(content, contains('50%'));
      expect(content, contains('█' * 5));
      expect(content, contains('░' * 5));
    });

    test('label is included in view when set', () {
      final p = ProgressModel(fraction: 0.5, label: 'Loading');
      expect(p.view().content, contains('Loading'));
    });

    test('update returns self unchanged', () {
      final p = ProgressModel(fraction: 0.3);
      final (next, cmd) = p.update(TickMsg(DateTime.now()));
      expect(identical(p, next), isTrue);
      expect(cmd, isNull);
    });

    test('assert throws for fraction < 0', () {
      expect(
          () => ProgressModel(fraction: -0.1), throwsA(isA<AssertionError>()));
    });

    test('assert throws for fraction > 1', () {
      expect(
          () => ProgressModel(fraction: 1.1), throwsA(isA<AssertionError>()));
    });

    test('three-stop gradients interpolate through every palette stop', () {
      final p = ProgressModel(
        fraction: 1,
        width: 5,
        colors: const [
          RgbColor(255, 0, 0),
          RgbColor(0, 255, 0),
          RgbColor(0, 0, 255),
        ],
      );

      final content = p.view().content;
      expect(content, contains('\x1b[38;2;255;0;0m'));
      expect(content, contains('\x1b[38;2;0;255;0m'));
      expect(content, contains('\x1b[38;2;0;0;255m'));
    });

    test('scaled gradients span the filled width only', () {
      const colors = [
        RgbColor(255, 0, 0),
        RgbColor(0, 255, 0),
        RgbColor(0, 0, 255),
      ];
      final scaled = ProgressModel(
        fraction: 0.6,
        width: 5,
        colors: colors,
        scaleGradient: true,
      ).view().content;
      final unscaled = ProgressModel(
        fraction: 0.6,
        width: 5,
        colors: colors,
      ).view().content;

      expect(scaled, contains('\x1b[38;2;0;0;255m'));
      expect(unscaled, isNot(contains('\x1b[38;2;0;0;255m')));
      expect(unscaled, contains('\x1b[38;2;0;255;0m'));
    });

    test('dynamic color callback overrides configured gradients', () {
      final calls = <(double, double)>[];
      final p = ProgressModel(
        fraction: 0.5,
        width: 4,
        colors: const [RgbColor(255, 0, 0), RgbColor(0, 255, 0)],
        styles: const ProgressStyles(
          filled: Style(
            foregroundComplete: CompleteColor(
              trueColor: RgbColor(255, 255, 0),
            ),
          ),
        ),
        colorBuilder: (total, current) {
          calls.add((total, current));
          return const RgbColor(0, 0, 255);
        },
      );

      final content = p.view().content;
      expect(calls, [(0.5, 0.0), (0.5, 0.25)]);
      expect(content, contains('\x1b[38;2;0;0;255m'));
      expect(content, isNot(contains('\x1b[38;2;255;0;0m')));
      expect(content, isNot(contains('\x1b[38;2;255;255;0m')));
    });

    test('one color becomes a solid fill and empty colors use filled style',
        () {
      final solid = ProgressModel(
        fraction: 1,
        width: 2,
        colors: const [RgbColor(1, 2, 3)],
      ).view().content;
      final fallback = ProgressModel(
        fraction: 1,
        width: 2,
        colors: const [],
        styles: const ProgressStyles(
          filled: Style(foregroundRgb: RgbColor(4, 5, 6)),
        ),
      ).view().content;

      expect(solid, contains('\x1b[38;2;1;2;3m'));
      expect(fallback, contains('\x1b[38;2;4;5;6m'));
    });

    test('gradient boundaries do not color empty cells or miss final stop', () {
      var calls = 0;
      final empty = ProgressModel(
        fraction: 0,
        width: 3,
        colorBuilder: (_, __) {
          calls++;
          return const RgbColor(1, 2, 3);
        },
      ).view().content;
      expect(calls, 0);
      expect(empty, isNot(contains('\x1b[38;2;1;2;3m')));

      final full = ProgressModel(
        fraction: 1,
        width: 3,
        colors: const [RgbColor(1, 2, 3), RgbColor(7, 8, 9)],
      ).view().content;
      expect(full, contains('\x1b[38;2;1;2;3m'));
      expect(full, contains('\x1b[38;2;7;8;9m'));
    });
  });
}
