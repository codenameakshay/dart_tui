import 'package:dart_tui/src/ansi_state.dart';
import 'package:dart_tui/src/bubbles/style.dart';
import 'package:test/test.dart';

void main() {
  group('SGR color operands', () {
    for (final code in [38, 48, 58]) {
      for (final operands in [
        '2;0;128;255',
        '2;255;0;128',
        '2;255;128;0',
        '2;0;0;0',
        '5;0',
      ]) {
        for (final suffix in ['', ';4']) {
          final sequence = '\x1b[$code;$operands${suffix}m';
          test('$code;$operands$suffix preserves preceding styling', () {
            final state = AnsiStateTracker()..accept('\x1b[1m');
            expect(state.sgrOpenSequence, '\x1b[1m');

            state.accept(sequence);

            expect(state.sgrOpenSequence, '\x1b[1m$sequence');
            expect(state.closeSequence, '\x1b[0m');
          });
        }
      }
    }

    test('multiple colors and colon subparameters are not resets', () {
      const sequence = '\x1b[38;2;0;128;0;48;5;0;58:2::0:0:0;4:3m';
      final state = AnsiStateTracker()
        ..accept('\x1b[1m')
        ..accept(sequence);

      expect(state.sgrOpenSequence, '\x1b[1m$sequence');
      expect(state.closeSequence, '\x1b[0m');
    });
  });

  group('actual SGR resets', () {
    for (final parameters in ['', '0', '00', '1;0', '38;2;255;128;0;0']) {
      test('$parameters clears active state', () {
        final state = AnsiStateTracker()..accept('\x1b[1m');
        expect(state.sgrOpenSequence, '\x1b[1m');

        state.accept('\x1b[${parameters}m');

        expect(state.sgrOpenSequence, isEmpty);
        expect(state.closeSequence, isEmpty);
      });
    }

    for (final parameters in ['1;0;32', ';32', '0;38;2;255;128;0']) {
      test('$parameters clears old state but retains new styling', () {
        final state = AnsiStateTracker()..accept('\x1b[3m');
        state.accept('\x1b[${parameters}m');

        expect(state.sgrOpenSequence, '\x1b[${parameters}m');
        expect(state.closeSequence, '\x1b[0m');
      });
    }
  });

  for (final color in ['38;2;255;128;0', '48;5;0', '58;2;0;255;0']) {
    final open = '\x1b[1m\x1b[${color}m';

    test('truncate closes zero-valued color $color', () {
      expect(truncate('${open}Hello world', 5), '${open}Hello\x1b[0m');
    });

    test('truncateLeft reopens zero-valued color $color', () {
      expect(truncateLeft('${open}Hello world', 5), '${open}world\x1b[0m');
    });

    test('line balancing closes and reopens zero-valued color $color', () {
      expect(
        balanceAnsiState('${open}Hello\nworld'),
        '${open}Hello\x1b[0m\n${open}world\x1b[0m',
      );
    });
  }
}
