import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg _key(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));

void main() {
  group('SpinnerModel', () {
    test('initial frame is first frame', () {
      final s = SpinnerModel();
      expect(s.index, 0);
    });

    test('update on TickMsg advances frame', () {
      final s = SpinnerModel();
      final (next, _) = s.update(TickMsg(DateTime.now()));
      final n = next as SpinnerModel;
      expect(n.index, 1);
    });

    test('frame wraps around after last frame', () {
      final frames = ['A', 'B', 'C'];
      var s = SpinnerModel(frames: frames, index: 2);
      final (next, _) = s.update(TickMsg(DateTime.now()));
      final n = next as SpinnerModel;
      expect(n.index, 0);
    });

    test('non-TickMsg does not change state', () {
      final s = SpinnerModel();
      final (next, _) = s.update(_key('q'));
      expect(identical(s, next), isTrue);
    });

    test('view renders current frame', () {
      final s = SpinnerModel(frames: ['X', 'Y'], index: 0);
      expect(s.view().content, contains('X'));
    });

    test('view renders prefix and suffix', () {
      final s = SpinnerModel(
        frames: ['*'],
        index: 0,
        prefix: 'PRE',
        suffix: 'SUF',
      );
      final content = s.view().content;
      expect(content, contains('PRE'));
      expect(content, contains('SUF'));
    });

    test('empty frames renders space between prefix and suffix', () {
      final s = SpinnerModel(frames: [], prefix: 'A', suffix: 'B');
      expect(s.view().content, contains('A'));
      expect(s.view().content, contains('B'));
    });

    test('update on TickMsg preserves prefix/suffix', () {
      final s = SpinnerModel(prefix: 'Loading', suffix: '...');
      final (next, _) = s.update(TickMsg(DateTime.now()));
      final n = next as SpinnerModel;
      expect(n.prefix, 'Loading');
      expect(n.suffix, '...');
    });
  });
}
