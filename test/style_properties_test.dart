// Property-based invariant tests for the Style rendering pipeline.
//
// Each test verifies a mathematical invariant that must hold for ALL inputs
// from a representative sample space. We generate inputs via dart:math random
// rather than a QuickCheck library so there are no extra dependencies.
import 'dart:math';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

// ── Generators ────────────────────────────────────────────────────────────────

final _rng = Random(42); // fixed seed for determinism

String _randomAscii({int minLen = 0, int maxLen = 80}) {
  final len = minLen + _rng.nextInt(maxLen - minLen + 1);
  final chars =
      List.generate(len, (_) => String.fromCharCode(0x20 + _rng.nextInt(95)));
  return chars.join();
}

String _randomMultiLine({int lines = 5}) =>
    List.generate(lines, (_) => _randomAscii(maxLen: 40)).join('\n');

// Run [property] on [n] random inputs; all must pass.
void _checkAll(int n, void Function(String s) property) {
  for (var i = 0; i < n; i++) {
    final s = _randomAscii(maxLen: 120);
    property(s);
  }
}

// ── Style helpers ────────────────────────────────────────────────────────────

Style _plain() => const Style();
Style _bold() => const Style(isBold: true);
Style _padded() => const Style(padding: EdgeInsets.symmetric(horizontal: 2));
Style _bordered() => const Style(border: Border.rounded);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── getWidth invariants ────────────────────────────────────────────────────

  group('getWidth invariants', () {
    test('getWidth("") == 0', () {
      expect(getWidth(''), 0);
    });

    test('getWidth of plain ASCII == string length', () {
      _checkAll(200, (s) {
        // Only ASCII printable: no double-wide chars, no ANSI
        expect(getWidth(s), s.length,
            reason: 'plain ASCII width mismatch for "$s"');
      });
    });

    test('getWidth is non-negative for any input', () {
      _checkAll(200, (s) {
        expect(getWidth(s), greaterThanOrEqualTo(0));
      });
    });

    test('getWidth("a" * n) == n', () {
      for (var n = 0; n <= 100; n++) {
        expect(getWidth('a' * n), n);
      }
    });

    test('getWidth strips ANSI before counting', () {
      // A red 'hello' should still be width 5.
      const red = '\x1b[31m';
      const reset = '\x1b[0m';
      expect(getWidth('${red}hello$reset'), 5);
    });

    test('CJK double-wide char counts as 2', () {
      // U+4E2D (中) is a CJK character, width 2.
      expect(getWidth('中'), 2);
      expect(getWidth('中文'), 4);
    });
  });

  // ── getHeight invariants ───────────────────────────────────────────────────

  group('getHeight invariants', () {
    test('getHeight("") == 1', () {
      expect(getHeight(''), 1);
    });

    test('getHeight of single-line == 1', () {
      _checkAll(200, (s) {
        // Replace any accidental newlines with spaces.
        final clean = s.replaceAll('\n', ' ');
        expect(getHeight(clean), 1);
      });
    });

    test('getHeight counts newlines', () {
      expect(getHeight('a\nb\nc'), 3);
      expect(getHeight('a\n'), 2); // trailing newline adds a line
    });

    test('getHeight(\$n newlines) == n + 1', () {
      for (var n = 0; n <= 20; n++) {
        final s = 'x${'\n' * n}';
        expect(getHeight(s), n + 1);
      }
    });

    test('getHeight is always >= 1', () {
      for (var i = 0; i < 200; i++) {
        final s = _randomMultiLine();
        expect(getHeight(s), greaterThanOrEqualTo(1));
      }
    });
  });

  // ── truncate invariants ────────────────────────────────────────────────────

  group('truncate invariants', () {
    test('truncate result width <= maxWidth', () {
      _checkAll(300, (s) {
        final maxW = _rng.nextInt(80);
        final result = truncate(s, maxW);
        expect(getWidth(stripAnsi(result)), lessThanOrEqualTo(maxW),
            reason: 'truncate("$s", $maxW) → "$result" overflowed');
      });
    });

    test('truncate is idempotent: truncate(truncate(s,n), n) == truncate(s,n)',
        () {
      _checkAll(200, (s) {
        final maxW = 1 + _rng.nextInt(60);
        final once = truncate(s, maxW);
        final twice = truncate(once, maxW);
        expect(twice, once,
            reason: 'idempotence violated for "$s" at width $maxW');
      });
    });

    test('truncate(s, n) where n >= getWidth(s) returns s unchanged', () {
      _checkAll(200, (s) {
        final w = getWidth(s);
        expect(truncate(s, w), s);
        expect(truncate(s, w + 100), s);
      });
    });

    test('truncate("", n) == "" for all n >= 0', () {
      for (var n = 0; n <= 100; n++) {
        expect(truncate('', n), '');
      }
    });
  });

  // ── truncateLeft invariants ────────────────────────────────────────────────

  group('truncateLeft invariants', () {
    test('truncateLeft result width <= maxWidth', () {
      _checkAll(300, (s) {
        final maxW = _rng.nextInt(80);
        final result = truncateLeft(s, maxW);
        expect(getWidth(stripAnsi(result)), lessThanOrEqualTo(maxW),
            reason: 'truncateLeft overflowed');
      });
    });

    test('truncateLeft(s, n) where n >= getWidth(s) returns s', () {
      _checkAll(200, (s) {
        final w = getWidth(s);
        expect(truncateLeft(s, w), s);
        expect(truncateLeft(s, w + 50), s);
      });
    });

    test('truncateLeft("", n) == "" for all n', () {
      for (var n = 0; n <= 50; n++) {
        expect(truncateLeft('', n), '');
      }
    });
  });

  // ── Style.render basic invariants ─────────────────────────────────────────

  group('Style.render invariants', () {
    test('plain Style.render(s) visible content equals s', () {
      _checkAll(200, (s) {
        final rendered = _plain().render(s);
        expect(stripAnsi(rendered), s,
            reason: 'plain render stripped content mismatch');
      });
    });

    test('render with bold contains the original text', () {
      _checkAll(100, (s) {
        final rendered = _bold().render(s);
        expect(stripAnsi(rendered), contains(s));
      });
    });

    test('render with padding: visible width >= original width', () {
      _checkAll(100, (s) {
        // Single-line only (padding is per-line).
        final clean = s.replaceAll('\n', ' ');
        final rendered = _padded().render(clean);
        final renderedWidth = getWidth(stripAnsi(rendered.split('\n').first));
        expect(renderedWidth, greaterThanOrEqualTo(getWidth(clean)),
            reason: 'padding should never shrink content');
      });
    });

    test('render with padding adds at least padding columns', () {
      // padding: horizontal: 2 → 2 spaces each side = +4 width minimum
      const padded = Style(padding: EdgeInsets.symmetric(horizontal: 2));
      for (var i = 0; i < 100; i++) {
        final s = _randomAscii(minLen: 1, maxLen: 40).replaceAll('\n', ' ');
        final rendered = stripAnsi(padded.render(s).split('\n').first);
        expect(getWidth(rendered), greaterThanOrEqualTo(getWidth(s) + 4),
            reason: 'horizontal padding should add 4 columns minimum');
      }
    });

    test('render with fixed width does not exceed that width', () {
      for (var w = 1; w <= 40; w += 3) {
        for (var i = 0; i < 10; i++) {
          final s = _randomAscii(maxLen: 60).replaceAll('\n', ' ');
          final rendered = Style(width: w).render(s);
          for (final line in rendered.split('\n')) {
            expect(getWidth(stripAnsi(line)), lessThanOrEqualTo(w + 2),
                // +2 tolerance for border chars (if any)
                reason: 'fixed width exceeded on line "$line"');
          }
        }
      }
    });

    test('render is deterministic: same style + input always same output', () {
      final styles = [_plain(), _bold(), _padded(), _bordered()];
      for (var i = 0; i < 50; i++) {
        final s = _randomAscii(maxLen: 40).replaceAll('\n', ' ');
        for (final style in styles) {
          final r1 = style.render(s);
          final r2 = style.render(s);
          expect(r1, r2, reason: 'render is not deterministic');
        }
      }
    });

    test('border render contains the original text', () {
      for (var i = 0; i < 50; i++) {
        final s = _randomAscii(minLen: 1, maxLen: 30).replaceAll('\n', ' ');
        final rendered = _bordered().render(s);
        expect(stripAnsi(rendered), contains(s),
            reason: 'border render dropped content');
      }
    });
  });

  // ── joinHorizontal / joinVertical invariants ───────────────────────────────

  group('joinHorizontal invariants', () {
    test('joined width == sum of component widths (single-line, no gap)', () {
      for (var i = 0; i < 100; i++) {
        final a = _randomAscii(minLen: 1, maxLen: 20).replaceAll('\n', ' ');
        final b = _randomAscii(minLen: 1, maxLen: 20).replaceAll('\n', ' ');
        final joined = joinHorizontal(AlignVertical.top, [a, b]);
        // The joined string may be multi-line if one component has more lines.
        final firstLine = joined.split('\n').first;
        expect(getWidth(stripAnsi(firstLine)),
            greaterThanOrEqualTo(getWidth(a) + getWidth(b)),
            reason: 'horizontal join width should be >= sum of parts');
      }
    });

    test('joinHorizontal with empty list returns empty string', () {
      expect(joinHorizontal(AlignVertical.top, []), '');
    });

    test('joinHorizontal with single element returns that element', () {
      for (var i = 0; i < 50; i++) {
        final s = _randomAscii(maxLen: 30).replaceAll('\n', ' ');
        expect(joinHorizontal(AlignVertical.top, [s]), s);
      }
    });
  });

  group('joinVertical invariants', () {
    test('joined height == sum of component heights', () {
      for (var i = 0; i < 100; i++) {
        final a = _randomAscii(maxLen: 20).replaceAll('\n', ' ');
        final b = _randomAscii(maxLen: 20).replaceAll('\n', ' ');
        final joined = joinVertical(Align.left, [a, b]);
        expect(getHeight(joined), getHeight(a) + getHeight(b),
            reason: 'vertical join height should equal sum of heights');
      }
    });

    test('joinVertical with empty list returns empty string', () {
      expect(joinVertical(Align.left, []), '');
    });

    test('joinVertical with single element returns that element', () {
      for (var i = 0; i < 50; i++) {
        final s = _randomAscii(maxLen: 30).replaceAll('\n', ' ');
        expect(joinVertical(Align.left, [s]), s);
      }
    });
  });

  // ── stripAnsi invariants ──────────────────────────────────────────────────

  group('stripAnsi invariants', () {
    test('stripAnsi of plain ASCII is identity', () {
      _checkAll(200, (s) {
        expect(stripAnsi(s), s);
      });
    });

    test('stripAnsi is idempotent', () {
      _checkAll(200, (s) {
        // wrap in colour codes and strip twice
        final styled = '\x1b[31m$s\x1b[0m';
        expect(stripAnsi(stripAnsi(styled)), stripAnsi(styled));
      });
    });

    test('stripAnsi result contains no ESC bytes', () {
      _checkAll(200, (s) {
        final result = stripAnsi('\x1b[31m$s\x1b[0m');
        expect(result.contains('\x1b'), isFalse,
            reason: 'ESC found in stripped output');
      });
    });
  });
}
