import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/input_decoder.dart';
import 'package:dart_tui/src/key_buffer_parser.dart';
import 'package:test/test.dart';

List<int> _b(String s) => s.codeUnits;

void main() {
  group('TerminalInputDecoder sequences', () {
    List<Msg> feed(String s) => TerminalInputDecoder().feed(_b(s));

    test('OSC color replies (10/11/12)', () {
      expect(feed('\x1b]10;rgb:ffff/0000/0000\x07').single,
          isA<ForegroundColorMsg>());
      expect(feed('\x1b]11;rgb:1234/5678/9abc\x07').single,
          isA<BackgroundColorMsg>());
      expect(
          feed('\x1b]12;rgb:0000/ffff/0000\x07').single, isA<CursorColorMsg>());
    });

    test('OSC 52 clipboard read reply', () {
      // base64('hi') == 'aGk='
      final msgs = feed('\x1b]52;c;aGk=\x07');
      expect(msgs.single, isA<ClipboardMsg>());
      expect((msgs.single as ClipboardMsg).content, 'hi');
    });

    test('DCS capability reply', () {
      // '\x1bP1+r<hex>=<hex>\x1b\\' — 626f6c64='bold', 31='1'
      final msgs = feed('\x1bP1+r626f6c64=31\x1b\\');
      expect(msgs.single, isA<CapabilityMsg>());
    });

    test('CSI cursor position + mode reports', () {
      expect(feed('\x1b[12;34R').single, isA<CursorPositionMsg>());
      expect(feed('\x1b[?2026;1\$y').single, isA<ModeReportMsg>());
      final unicodeMode = feed('\x1b[?2027;1\$y');
      expect(unicodeMode.single, isA<ModeReportMsg>());
      expect(unicodeMode.whereType<KeyboardEnhancementsMsg>(), isEmpty);
      expect(feed('\x1b[>1;95;0c').single, isA<TerminalVersionMsg>());
    });

    test('SGR mouse press/release/wheel/motion', () {
      expect(feed('\x1b[<0;10;20M').single, isA<MouseClickMsg>());
      expect(feed('\x1b[<0;10;20m').single, isA<MouseReleaseMsg>());
      expect(feed('\x1b[<64;5;5M').single, isA<MouseWheelMsg>());
      expect(feed('\x1b[<35;5;5M').single, isA<MouseMotionMsg>());
      // modifier bits (shift/alt/ctrl) on a click
      final mod = feed('\x1b[<28;1;1M').single as MouseClickMsg;
      expect(mod.mouse.modifiers, isNotEmpty);
    });

    test('focus in/out and bracketed paste', () {
      expect(feed('\x1b[I').single, isA<FocusMsg>());
      expect(feed('\x1b[O').single, isA<BlurMsg>());
      final paste = feed('\x1b[200~hello\x1b[201~');
      expect(paste.whereType<PasteStartMsg>(), isNotEmpty);
      expect(paste.whereType<PasteMsg>().single.content, 'hello');
      expect(paste.whereType<PasteEndMsg>(), isNotEmpty);
    });

    test('plain rune produces a key press', () {
      expect(feed('a').single, isA<KeyPressMsg>());
    });

    test('fragmented sequence across feeds', () {
      final d = TerminalInputDecoder();
      expect(d.feed(_b('\x1b]11;rgb:1111')), isEmpty); // partial
      final rest = d.feed(_b('/2222/3333\x07'));
      expect(rest.single, isA<BackgroundColorMsg>());
    });
  });

  group('parseKeyFromBuffer', () {
    TeaKey? parse(List<int> b) => parseKeyFromBuffer(b);

    test('control characters', () {
      expect(parse([0x01])!.keystroke(), 'ctrl+a');
      expect(parse([0x09])!.code, KeyCode.tab);
      expect(parse([0x0d])!.code, KeyCode.enter);
      expect(parse([0x0a])!.code, KeyCode.enter);
    });

    test('arrows, SS3 function keys, and nav sequences', () {
      expect(parse([0x1b, 0x5b, 0x41])!.code, KeyCode.up);
      expect(parse([0x1b, 0x5b, 0x44])!.code, KeyCode.left);
      expect(parse([0x1b, 0x4f, 0x50])!.code, KeyCode.f1);
      expect(parse([0x1b, 0x5b, 0x33, 0x7e])!.code, KeyCode.delete);
      expect(parse([0x1b, 0x5b, 0x35, 0x7e])!.code, KeyCode.pageUp);
    });

    test('alt combinations and backspace', () {
      expect(parse([0x1b, 0x62])!.modifiers, contains(KeyMod.alt));
      expect(parse([0x1b, 0x66])!.modifiers, contains(KeyMod.alt));
      expect(parse([0x1b, 0x7f])!.code, KeyCode.backspace);
      expect(parse([0x7f])!.code, KeyCode.backspace);
    });

    test('utf-8 multibyte rune and incomplete escape', () {
      expect(parse([0xc3, 0xa9])!.text, 'é');
      expect(parse([0x1b]), isNull); // needs more bytes
      expect(parse([0x00])!.code, KeyCode.unknown);
    });
  });
}
