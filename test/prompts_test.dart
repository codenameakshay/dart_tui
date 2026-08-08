import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

/// Input stream that emits each keystroke as its own event. Multi-byte escape
/// sequences (arrows) stay grouped; single printable bytes are separate events
/// so [parseKeyFromBuffer] doesn't greedily fold them into one multi-char rune.
Stream<List<int>> _seq(List<List<int>> chunks) => Stream.fromIterable(chunks);

const _enter = [0x0d];
const _ctrlC = [0x03];
const _backspace = [0x7f];
const _down = [0x1b, 0x5b, 0x42]; // ESC [ B

List<ProgramOption> _opts(List<List<int>> chunks) =>
    [withoutRenderer(), withInput(_seq(chunks))];

const _timeout = Timeout(Duration(seconds: 5));

void main() {
  group('promptSelect', () {
    test('down + enter selects the second choice', () async {
      final r =
          await promptSelect(['a', 'b', 'c'], options: _opts([_down, _enter]));
      expect(r, 'b');
    }, timeout: _timeout);

    test('ctrl+c cancels and returns null', () async {
      final r = await promptSelect(['a', 'b', 'c'], options: _opts([_ctrlC]));
      expect(r, isNull);
    }, timeout: _timeout);

    test('empty choices returns null immediately', () async {
      expect(await promptSelect([]), isNull);
    });
  });

  group('promptConfirm', () {
    test('y returns true', () async {
      final r = await promptConfirm('ok?',
          options: _opts([
            [0x79]
          ]));
      expect(r, isTrue);
    }, timeout: _timeout);

    test('n returns false', () async {
      final r = await promptConfirm('ok?',
          options: _opts([
            [0x6e]
          ]));
      expect(r, isFalse);
    }, timeout: _timeout);

    test('ctrl+c cancels', () async {
      final r = await promptConfirm('ok?', options: _opts([_ctrlC]));
      expect(r, isNull);
    }, timeout: _timeout);
  });

  group('promptInput', () {
    test('typing then enter returns the value', () async {
      final r = await promptInput('name',
          options: _opts([
            [0x68],
            [0x69],
            _enter
          ]));
      expect(r, 'hi');
    }, timeout: _timeout);

    test('backspace deletes before enter', () async {
      final r = await promptInput('name',
          options: _opts([
            [0x68],
            [0x69],
            _backspace,
            _enter
          ]));
      expect(r, 'h');
    }, timeout: _timeout);

    test('ctrl+c cancels', () async {
      final r = await promptInput('name', options: _opts([_ctrlC]));
      expect(r, isNull);
    }, timeout: _timeout);
  });
}
