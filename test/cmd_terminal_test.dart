// Tests for cmd-based terminal control messages.
import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/cmd.dart';
import 'package:test/test.dart';

void main() {
  group('Terminal control Cmd helpers', () {
    test('enterAltScreen() returns EnterAltScreenMsg', () {
      expect(enterAltScreen(), isA<EnterAltScreenMsg>());
    });

    test('exitAltScreen() returns ExitAltScreenMsg', () {
      expect(exitAltScreen(), isA<ExitAltScreenMsg>());
    });

    test('hideCursor() returns HideCursorMsg', () {
      expect(hideCursor(), isA<HideCursorMsg>());
    });

    test('showCursor() returns ShowCursorMsg', () {
      expect(showCursor(), isA<ShowCursorMsg>());
    });

    test('setWindowTitle() returns SetWindowTitleMsg with correct title',
        () async {
      final cmd = setWindowTitle('My App');
      final msg = await Future<dynamic>.value(cmd());
      expect(msg, isA<SetWindowTitleMsg>());
      final titleMsg = msg as SetWindowTitleMsg;
      expect(titleMsg.title, equals('My App'));
    });

    test('clearScrollArea() returns ClearScrollAreaMsg', () {
      expect(clearScrollArea(), isA<ClearScrollAreaMsg>());
    });

    test('scrollUp() returns ScrollMsg with up=true', () async {
      final cmd = scrollUp(3);
      final msg = await Future<dynamic>.value(cmd());
      expect(msg, isA<ScrollMsg>());
      final scrollMsg = msg as ScrollMsg;
      expect(scrollMsg.up, isTrue);
      expect(scrollMsg.lines, equals(3));
    });

    test('scrollDown() returns ScrollMsg with up=false', () async {
      final cmd = scrollDown(2);
      final msg = await Future<dynamic>.value(cmd());
      expect(msg, isA<ScrollMsg>());
      final scrollMsg = msg as ScrollMsg;
      expect(scrollMsg.up, isFalse);
      expect(scrollMsg.lines, equals(2));
    });

    test('scrollUp defaults to 1 line', () async {
      final cmd = scrollUp();
      final msg = await Future<dynamic>.value(cmd()) as ScrollMsg;
      expect(msg.lines, equals(1));
    });

    test('scrollDown defaults to 1 line', () async {
      final cmd = scrollDown();
      final msg = await Future<dynamic>.value(cmd()) as ScrollMsg;
      expect(msg.lines, equals(1));
    });
  });
}
