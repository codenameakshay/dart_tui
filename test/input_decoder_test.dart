// Edge-case and fuzz-style tests for TerminalInputDecoder.
//
// The decoder receives raw stdin bytes and must return correct Msg events
// across many fragmented / boundary / malformed inputs without throwing.
import 'dart:convert';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

import 'package:dart_tui/src/input_decoder.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

List<int> _str(String s) => utf8.encode(s);

// Feed bytes one at a time (worst-case fragmentation).
List<Msg> _feedBytewise(TerminalInputDecoder d, List<int> data) {
  final out = <Msg>[];
  for (final b in data) {
    out.addAll(d.feed([b]));
  }
  return out;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Basic ASCII / printable ──────────────────────────────────────────────

  group('ASCII printable', () {
    test('single letter produces KeyPressMsg with rune', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(_str('a'));
      expect(msgs, hasLength(1));
      final k = msgs[0] as KeyPressMsg;
      expect(k.keyEvent.code, KeyCode.rune);
      expect(k.keyEvent.text, 'a');
    });

    test('multiple letters in one chunk: decoder greedily combines printable ASCII', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(_str('xyz'));
      // The key buffer parser greedily decodes as many UTF-8 bytes as possible
      // in one pass, so a single chunk of printable ASCII becomes 1 KeyPressMsg.
      expect(msgs, hasLength(1));
      expect((msgs[0] as KeyPressMsg).keyEvent.text, 'xyz');
    });

    test('letters fed one at a time each become a separate KeyPressMsg', () {
      final d = TerminalInputDecoder();
      final msgs = _feedBytewise(d, _str('xyz'));
      expect(msgs, hasLength(3));
      final texts = msgs.map((m) => (m as KeyPressMsg).keyEvent.text).toList();
      expect(texts, ['x', 'y', 'z']);
    });

    test('space character produces rune KeyPressMsg with text=" "', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(_str(' '));
      expect(msgs, hasLength(1));
      final k = msgs[0] as KeyPressMsg;
      expect(k.keyEvent.text, ' ');
    });

    test('digit characters in one chunk are greedy-decoded as one message', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(_str('123'));
      expect(msgs, hasLength(1));
      expect((msgs[0] as KeyPressMsg).keyEvent.text, '123');
    });
  });

  // ── Arrow keys and special keys ──────────────────────────────────────────

  group('Special keys via CSI', () {
    test('ESC [ A → up arrow', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed([0x1b, 0x5b, 0x41]); // ESC [ A
      expect(msgs, hasLength(1));
      final k = msgs[0] as KeyPressMsg;
      expect(k.keyEvent.code, KeyCode.up);
    });

    test('ESC [ B → down arrow', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed([0x1b, 0x5b, 0x42]);
      expect(msgs, hasLength(1));
      expect((msgs[0] as KeyPressMsg).keyEvent.code, KeyCode.down);
    });

    test('ESC [ C → right arrow', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed([0x1b, 0x5b, 0x43]);
      expect(msgs, hasLength(1));
      expect((msgs[0] as KeyPressMsg).keyEvent.code, KeyCode.right);
    });

    test('ESC [ D → left arrow', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed([0x1b, 0x5b, 0x44]);
      expect(msgs, hasLength(1));
      expect((msgs[0] as KeyPressMsg).keyEvent.code, KeyCode.left);
    });
  });

  // ── Focus events ─────────────────────────────────────────────────────────

  group('Focus events', () {
    test('ESC [ I → FocusMsg', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed([0x1b, 0x5b, 0x49]);
      expect(msgs, hasLength(1));
      expect(msgs[0], isA<FocusMsg>());
    });

    test('ESC [ O → BlurMsg', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed([0x1b, 0x5b, 0x4f]);
      expect(msgs, hasLength(1));
      expect(msgs[0], isA<BlurMsg>());
    });

    test('focus then text', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed([0x1b, 0x5b, 0x49, 0x61]); // ESC[I + 'a'
      expect(msgs, hasLength(2));
      expect(msgs[0], isA<FocusMsg>());
      expect(msgs[1], isA<KeyPressMsg>());
    });
  });

  // ── Paste sequences ───────────────────────────────────────────────────────

  group('Bracketed paste', () {
    List<int> paste(String content) => [
          // ESC [ 2 0 0 ~
          0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7e,
          ..._str(content),
          // ESC [ 2 0 1 ~
          0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7e,
        ];

    test('basic paste produces PasteStartMsg, PasteMsg, PasteEndMsg', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(paste('hello'));
      expect(msgs, hasLength(3));
      expect(msgs[0], isA<PasteStartMsg>());
      expect((msgs[1] as PasteMsg).content, 'hello');
      expect(msgs[2], isA<PasteEndMsg>());
    });

    test('empty paste content', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(paste(''));
      expect(msgs, hasLength(3));
      expect((msgs[1] as PasteMsg).content, '');
    });

    test('paste with newline and special characters', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(paste('foo\nbar\t!'));
      expect((msgs[1] as PasteMsg).content, 'foo\nbar\t!');
    });

    test('paste fed byte-by-byte still works', () {
      final d = TerminalInputDecoder();
      final data = paste('byte');
      final msgs = _feedBytewise(d, data);
      expect(msgs, hasLength(3));
      expect((msgs[1] as PasteMsg).content, 'byte');
    });

    test('partial paste start leaves no output until complete', () {
      final d = TerminalInputDecoder();
      // feed only part of ESC [ 2 0 0 ~
      final partial = d.feed([0x1b, 0x5b, 0x32, 0x30]);
      expect(partial, isEmpty);
      // completing it should emit PasteStartMsg
      final rest = d.feed([0x30, 0x7e]);
      expect(rest, hasLength(1));
      expect(rest[0], isA<PasteStartMsg>());
    });
  });

  // ── Mouse events (SGR) ───────────────────────────────────────────────────

  group('SGR mouse events', () {
    // ESC [ < Cb ; Cx ; Cy M  (click)  or m (release)
    List<int> sgr(int cb, int cx, int cy, {bool release = false}) {
      final term = release ? 'm' : 'M';
      return _str('\x1b[<$cb;$cx;$cy$term');
    }

    test('left button click at (2, 3)', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(sgr(0, 3, 4)); // 1-based coords
      expect(msgs, hasLength(1));
      final m = msgs[0] as MouseClickMsg;
      expect(m.mouse.button, MouseButton.left);
      expect(m.mouse.x, 2); // 1-based → 0-based
      expect(m.mouse.y, 3);
    });

    test('right button click', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(sgr(2, 1, 1));
      expect(msgs, hasLength(1));
      expect((msgs[0] as MouseClickMsg).mouse.button, MouseButton.right);
    });

    test('left button release', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(sgr(0, 5, 10, release: true));
      expect(msgs, hasLength(1));
      expect(msgs[0], isA<MouseReleaseMsg>());
    });

    test('wheel up (cb=64)', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(sgr(64, 1, 1));
      expect(msgs, hasLength(1));
      expect((msgs[0] as MouseWheelMsg).mouse.button, MouseButton.wheelUp);
    });

    test('wheel down (cb=65)', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(sgr(65, 1, 1));
      expect(msgs, hasLength(1));
      expect((msgs[0] as MouseWheelMsg).mouse.button, MouseButton.wheelDown);
    });

    test('shift modifier (cb=4)', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(sgr(4, 1, 1));
      expect(msgs, hasLength(1));
      final m = msgs[0] as MouseClickMsg;
      expect(m.mouse.modifiers, contains(KeyMod.shift));
    });

    test('alt modifier (cb=8)', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(sgr(8, 1, 1));
      expect(msgs, hasLength(1));
      expect((msgs[0] as MouseClickMsg).mouse.modifiers, contains(KeyMod.alt));
    });

    test('ctrl modifier (cb=16)', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(sgr(16, 1, 1));
      expect(msgs, hasLength(1));
      expect((msgs[0] as MouseClickMsg).mouse.modifiers, contains(KeyMod.ctrl));
    });

    test('zero-coords clamped to (0, 0) rather than negative', () {
      final d = TerminalInputDecoder();
      // cx=0, cy=0 in 1-based is illegal; decoder should clamp to 0
      final msgs = d.feed(_str('\x1b[<0;0;0M'));
      expect(msgs, hasLength(1));
      final m = msgs[0] as MouseClickMsg;
      expect(m.mouse.x, 0);
      expect(m.mouse.y, 0);
    });
  });

  // ── Lone ESC handling ────────────────────────────────────────────────────

  group('Lone ESC', () {
    test('single ESC byte leaves hasPendingLoneEscape = true', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed([0x1b]);
      expect(msgs, isEmpty);
      expect(d.hasPendingLoneEscape, isTrue);
    });

    test('takeLoneEscapeIfStillPending emits Escape key', () {
      final d = TerminalInputDecoder();
      d.feed([0x1b]);
      final msgs = d.takeLoneEscapeIfStillPending();
      expect(msgs, hasLength(1));
      expect((msgs[0] as KeyPressMsg).keyEvent.code, KeyCode.escape);
      expect(d.hasPendingLoneEscape, isFalse);
    });

    test('ESC followed immediately by [ is not a lone escape', () {
      final d = TerminalInputDecoder();
      d.feed([0x1b]);
      expect(d.hasPendingLoneEscape, isTrue);
      // Now feeding the rest of an arrow key
      final msgs = d.feed([0x5b, 0x41]);
      expect(msgs, hasLength(1));
      expect((msgs[0] as KeyPressMsg).keyEvent.code, KeyCode.up);
      expect(d.hasPendingLoneEscape, isFalse);
    });

    test('takeLoneEscapeIfStillPending is idempotent after clear', () {
      final d = TerminalInputDecoder();
      d.feed([0x1b]);
      d.takeLoneEscapeIfStillPending();
      expect(d.takeLoneEscapeIfStillPending(), isEmpty);
    });
  });

  // ── Cursor position report ───────────────────────────────────────────────

  group('Cursor position report (DSR response)', () {
    test('ESC [ row ; col R → CursorPositionMsg (0-based)', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(_str('\x1b[5;10R'));
      expect(msgs, hasLength(1));
      final c = msgs[0] as CursorPositionMsg;
      expect(c.y, 4); // row 5 → index 4
      expect(c.x, 9); // col 10 → index 9
    });

    test('row/col 1;1 → (0, 0)', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(_str('\x1b[1;1R'));
      final c = msgs[0] as CursorPositionMsg;
      expect(c.x, 0);
      expect(c.y, 0);
    });
  });

  // ── OSC sequences ────────────────────────────────────────────────────────

  group('OSC color queries', () {
    List<int> oscBel(String body) => [
          0x1b, 0x5d, // ESC ]
          ..._str(body),
          0x07, // BEL
        ];

    List<int> oscSt(String body) => [
          0x1b, 0x5d, // ESC ]
          ..._str(body),
          0x1b, 0x5c, // ST
        ];

    test('OSC 10 foreground color via BEL', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(oscBel('10;rgb:ff/80/00'));
      expect(msgs, hasLength(1));
      expect(msgs[0], isA<ForegroundColorMsg>());
    });

    test('OSC 11 background color via ST', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(oscSt('11;rgb:00/00/ff'));
      expect(msgs, hasLength(1));
      expect(msgs[0], isA<BackgroundColorMsg>());
    });

    test('OSC 12 cursor color', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(oscBel('12;rgb:aa/bb/cc'));
      expect(msgs, hasLength(1));
      expect(msgs[0], isA<CursorColorMsg>());
    });

    test('unknown OSC number produces no message', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(oscBel('99;something'));
      expect(msgs, isEmpty);
    });

    test('partial OSC holds output until complete', () {
      final d = TerminalInputDecoder();
      // Feed without the terminator
      final partial = d.feed([0x1b, 0x5d, ..._str('10;rgb:ff/80/00')]);
      expect(partial, isEmpty);
      // Complete with BEL
      final complete = d.feed([0x07]);
      expect(complete, hasLength(1));
      expect(complete[0], isA<ForegroundColorMsg>());
    });
  });

  // ── Chunking and fragmentation ───────────────────────────────────────────

  group('Fragmented input', () {
    test('arrow key split across two feeds', () {
      final d = TerminalInputDecoder();
      final first = d.feed([0x1b, 0x5b]); // ESC [
      expect(first, isEmpty);
      final second = d.feed([0x41]); // A
      expect(second, hasLength(1));
      expect((second[0] as KeyPressMsg).keyEvent.code, KeyCode.up);
    });

    test('two arrow keys in one buffer', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed([0x1b, 0x5b, 0x41, 0x1b, 0x5b, 0x42]);
      expect(msgs, hasLength(2));
      expect((msgs[0] as KeyPressMsg).keyEvent.code, KeyCode.up);
      expect((msgs[1] as KeyPressMsg).keyEvent.code, KeyCode.down);
    });

    test('text then arrow key in separate feeds produce separate messages', () {
      final d = TerminalInputDecoder();
      final first = d.feed([0x68]); // 'h'
      expect(first, hasLength(1));
      expect((first[0] as KeyPressMsg).keyEvent.text, 'h');
      final second = d.feed([0x1b, 0x5b, 0x41]); // ESC[A = up
      expect(second, hasLength(1));
      expect((second[0] as KeyPressMsg).keyEvent.code, KeyCode.up);
    });

    test('many keys fed one byte at a time', () {
      final d = TerminalInputDecoder();
      final data = [0x61, 0x62, 0x63, 0x1b, 0x5b, 0x41]; // a b c UP
      final msgs = _feedBytewise(d, data);
      expect(msgs, hasLength(4));
    });
  });

  // ── Malformed / garbage input ────────────────────────────────────────────

  group('Malformed input resilience', () {
    test('unrecognised CSI sequence does not hang or throw', () {
      final d = TerminalInputDecoder();
      // ESC [ 9 9 Z — _decodeCsi returns [] for unknown sequences;
      // the parser falls through to key_buffer_parser which partially consumes it.
      // The key thing is: no exception, no infinite loop, the buffer is consumed.
      expect(() => d.feed([0x1b, 0x5b, 0x39, 0x39, 0x5a]), returnsNormally);
    });

    test('high bytes (non-ASCII) are decoded without throwing', () {
      final d = TerminalInputDecoder();
      // UTF-8 for euro sign (E2 82 AC)
      expect(() => d.feed([0xe2, 0x82, 0xac]), returnsNormally);
    });

    test('null byte is handled gracefully', () {
      final d = TerminalInputDecoder();
      expect(() => d.feed([0x00]), returnsNormally);
    });

    test('empty feed returns empty list', () {
      final d = TerminalInputDecoder();
      expect(d.feed([]), isEmpty);
    });

    test('decoder state resets correctly across many calls', () {
      final d = TerminalInputDecoder();
      for (var i = 0; i < 100; i++) {
        d.feed(_str('a'));
      }
      final msgs = d.feed(_str('z'));
      expect(msgs, hasLength(1));
      expect((msgs[0] as KeyPressMsg).keyEvent.text, 'z');
    });
  });

  // ── Mode report ──────────────────────────────────────────────────────────

  group('Mode report (DECRPM)', () {
    test('ESC [ ? 2026 ; 1 \$y → ModeReportMsg', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(_str('\x1b[?2026;1\$y'));
      expect(msgs.any((m) => m is ModeReportMsg), isTrue);
      final m = msgs.firstWhere((m) => m is ModeReportMsg) as ModeReportMsg;
      expect(m.mode, 2026);
      expect(m.value, 1);
    });

    test('keyboard enhancements report (mode 2027) also emits KeyboardEnhancementsMsg', () {
      final d = TerminalInputDecoder();
      final msgs = d.feed(_str('\x1b[?2027;1\$y'));
      expect(msgs.any((m) => m is ModeReportMsg), isTrue);
      expect(msgs.any((m) => m is KeyboardEnhancementsMsg), isTrue);
    });
  });
}
