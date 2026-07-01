# Performance Hot-Path Wins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the verified per-frame and per-keystroke allocation/CPU hot spots in dart_tui's text-measurement, wrapping, rendering, and component-copy paths, with zero observable behavior change.

**Architecture:** These are behavior-preserving refactors. Every task pins the current observable output with a test that must pass before AND after the change; where a new observable exists (memoization identity) the test is genuine red→green. Correctness (ANSI-safety, grapheme handling, diff output) is the hard constraint — no optimization that risks it survives.

**Tech Stack:** Dart ≥3.5, `package:characters`, `package:test`. Run tests with `dart test`; analyze with `dart analyze`; format with `dart format`.

**Scope note:** This is plan 1 of 4 for the release (perf → coverage → cheap-widgets → forms). It targets only the fixes the adversarial review confirmed as *real and worthwhile*. Refuted findings (null-microtask guard, tick coalescing, StreamController removal, drain-starvation, etc.) are intentionally excluded. Fiddlier medium-value fixes are listed in the Deferred appendix, not implemented here.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `lib/src/bubbles/style.dart` | ANSI strip + visible-width + truncate helpers (hottest measurement path) | Modify `stripAnsi`, `_visibleWidth`, `_truncateVisible`, `truncateLeft`; add `_graphemeWidth` |
| `lib/src/bubbles/viewport.dart` | Scrollable pane; wraps content | Add private ctor; memoize `_wrappedLines` across scroll; fast-path per-line ANSI strip |
| `lib/src/renderer.dart` | ANSI + Cell renderers (per-frame output) | Content-guard early-return in both; drop redundant list copy |
| `lib/src/bubbles/list.dart` | Filtered list | Memoize `filteredItems` as `late final` |
| `lib/src/bubbles/tree.dart` | Tree flatten | Reuse `_flat` in `_copyWith` when `root` unchanged |
| `lib/src/program.dart` | Event loop render throttle | Precompute frame budget; monotonic `Stopwatch` clock |
| `test/perf_hotpath_test.dart` | New behavior-pinning tests for all of the above | Create |

Each task is self-contained and independently committable.

---

### Task 1: style.dart — ANSI fast-path + single-grapheme width helper

The regex `stripAnsi` runs on every `_visibleWidth` call, and `_visibleWidth` is called **per line and per grapheme** across wrapping, truncation, padding, and `joinHorizontal`. Add a cheap `!s.contains('\x1b')` fast path and a dedicated single-grapheme width helper that skips the strip entirely.

**Files:**
- Modify: `lib/src/bubbles/style.dart:1026` (`stripAnsi`), `:1087` (`_visibleWidth`), `:1132` (`_truncateVisible`), `:1060` & `:1077` (`truncateLeft`)
- Test: `test/perf_hotpath_test.dart`

- [ ] **Step 1: Write the behavior-pinning + correctness test**

Create `test/perf_hotpath_test.dart`:

```dart
import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('style width/strip fast-path (Task 1)', () {
    test('stripAnsi is identity for strings with no escape', () {
      const plain = 'hello world — no escapes here';
      expect(stripAnsi(plain), plain);
    });

    test('stripAnsi still removes SGR sequences', () {
      expect(stripAnsi('\x1b[1;32mgreen\x1b[0m'), 'green');
    });

    test('getWidth matches for plain, ANSI, and double-width', () {
      expect(getWidth('abc'), 3);
      expect(getWidth('\x1b[31mabc\x1b[0m'), 3);
      expect(getWidth('你好'), 4); // two double-width CJK
      expect(getWidth('a你b'), 4);
    });

    test('truncate preserves ANSI and respects visible width', () {
      expect(truncate('abcdef', 3), 'abc');
      expect(truncate('\x1b[31mabcdef\x1b[0m', 3), '\x1b[31mabc');
      expect(truncate('你好世界', 4), '你好'); // 2 cols each
    });

    test('truncateLeft keeps the trailing columns', () {
      expect(truncateLeft('abcdef', 3), 'def');
      expect(truncateLeft('你好世界', 4), '世界');
    });
  });
}
```

- [ ] **Step 2: Run the test against current code to establish the baseline**

Run: `dart test test/perf_hotpath_test.dart -n "style width"`
Expected: PASS (these assertions hold on the current implementation — they exist to catch any regression the refactor introduces).

- [ ] **Step 3: Apply the fast-path + helper**

In `lib/src/bubbles/style.dart`, replace `stripAnsi`:

```dart
/// Strip ANSI escape sequences from [s].
String stripAnsi(String s) {
  if (!s.contains('\x1b')) return s;
  return s.replaceAll(_ansiEscapeRe, '');
}
```

Add the single-grapheme helper directly below `_isDoubleWidth` (after line 1112):

```dart
/// Visible column width (1 or 2) of a single grapheme cluster [g].
///
/// Callers pass raw graphemes that never contain ANSI escapes, so this skips
/// [stripAnsi] entirely — the hot inner-loop replacement for `_visibleWidth(char)`.
int _graphemeWidth(String g) => _isDoubleWidth(g.runes.first) ? 2 : 1;
```

In `_truncateVisible`, change line 1132 from `final charWidth = _visibleWidth(char);` to:

```dart
    final charWidth = _graphemeWidth(char);
```

In `truncateLeft`, change line 1060 (`consumed += _visibleWidth(char);`) and line 1077 (`final w = _visibleWidth(char);`) to use `_graphemeWidth`:

```dart
    consumed += _graphemeWidth(char);
```
```dart
    final w = _graphemeWidth(char);
```

- [ ] **Step 4: Run tests + analyze**

Run: `dart test test/perf_hotpath_test.dart -n "style width" && dart test test/style_test.dart test/style_properties_test.dart test/style_wordwrap_test.dart && dart analyze lib/src/bubbles/style.dart`
Expected: all PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/bubbles/style.dart test/perf_hotpath_test.dart
git commit -m "perf(style): ANSI fast-path in stripAnsi + single-grapheme width helper"
```

---

### Task 2: viewport.dart — memoize wrapped lines across scroll; fast-path per-line strip

Currently every scroll rebuilds the model through the public constructor, which re-wraps the **entire** content and runs a regex ANSI strip per line. Scrolling changes only `yOffset`/`xOffset` — wrapping is unaffected. Thread the precomputed `_wrappedLines` through scroll-only rebuilds via a private constructor.

**Files:**
- Modify: `lib/src/bubbles/viewport.dart` (add `_withWrapped` ctor; `_clamp`, xOffset path, `_computeWrapped`)
- Test: `test/perf_hotpath_test.dart`

- [ ] **Step 1: Write the behavior-pinning test**

Append to `test/perf_hotpath_test.dart` inside `main()`:

```dart
  group('viewport wrap memoization (Task 2)', () {
    test('soft-wrap splits a long line to width', () {
      final vp = ViewportModel(
          content: 'aaaaaaaaaa', width: 4, height: 10, softWrap: true);
      expect(vp.totalLines, 3); // 4 + 4 + 2
    });

    test('scrolling preserves wrapped content and window', () {
      final content = List.generate(20, (i) => 'line$i').join('\n');
      final vp =
          ViewportModel(content: content, width: 80, height: 5, softWrap: true);
      final scrolled = vp.scrollBy(3);
      expect(scrolled.totalLines, 20);
      expect(scrolled.view().content.split('\n').first, 'line3');
      expect(scrolled.view().content.split('\n').length, 5);
    });

    test('setContent re-wraps', () {
      final vp = ViewportModel(content: 'a', width: 4, height: 10);
      final vp2 = vp.setContent('aaaaaaaa');
      expect(vp2.totalLines, 2);
    });
  });
```

- [ ] **Step 2: Run to establish baseline**

Run: `dart test test/perf_hotpath_test.dart -n "viewport wrap"`
Expected: PASS on current code (behavior must be preserved by the refactor).

- [ ] **Step 3: Add the private ctor and thread memoized lines through scroll**

In `lib/src/bubbles/viewport.dart`, add a private constructor immediately after the public constructor (after line 16):

```dart
  ViewportModel._withWrapped({
    required this.content,
    required this.width,
    required this.height,
    required this.yOffset,
    required this.xOffset,
    required this.softWrap,
    required List<String> wrappedLines,
  }) : _wrappedLines = wrappedLines;
```

Replace `_clamp` (lines 86-89) so it reuses the cached lines:

```dart
  ViewportModel _clamp(int yOff) {
    final clamped = yOff.clamp(0, (totalLines - height).clamp(0, totalLines));
    return ViewportModel._withWrapped(
      content: content,
      width: width,
      height: height,
      yOffset: clamped,
      xOffset: xOffset,
      softWrap: softWrap,
      wrappedLines: _wrappedLines,
    );
  }
```

In `update()`, replace the two xOffset rebuilds (lines 140 and 144) — these do not affect wrapping, so reuse the cache:

```dart
      case 'left':
        if (!softWrap) {
          return (
            ViewportModel._withWrapped(
              content: content,
              width: width,
              height: height,
              yOffset: yOffset,
              xOffset: (xOffset - 1).clamp(0, 9999),
              softWrap: softWrap,
              wrappedLines: _wrappedLines,
            ),
            null,
          );
        }
        return (this, null);
      case 'right':
        if (!softWrap) {
          return (
            ViewportModel._withWrapped(
              content: content,
              width: width,
              height: height,
              yOffset: yOffset,
              xOffset: xOffset + 1,
              softWrap: softWrap,
              wrappedLines: _wrappedLines,
            ),
            null,
          );
        }
        return (this, null);
```

Fast-path the per-line ANSI strip in `_computeWrapped` (lines 33-34):

```dart
      final stripped =
          line.contains('\x1b') ? line.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '') : line;
```

`setContent` (line 109-110) already routes through `_rebuild` → public constructor, which correctly re-wraps. Leave it as-is. `_rebuild` remains for `setContent`; only the scroll/xOffset paths now bypass it.

- [ ] **Step 4: Run tests + analyze**

Run: `dart test test/perf_hotpath_test.dart -n "viewport wrap" && dart test test/viewport_test.dart && dart analyze lib/src/bubbles/viewport.dart`
Expected: all PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/bubbles/viewport.dart test/perf_hotpath_test.dart
git commit -m "perf(viewport): reuse wrapped lines across scroll; fast-path ANSI strip"
```

---

### Task 3: renderer.dart — CellRenderer content guard

`CellRenderer.render` rebuilds the whole grid and walks every cell on every frame, even when `view.content` is identical to the last frame. Add a content guard **after** `_applyModes` and the title write (so mode changes still apply), mirroring `AnsiRenderer`.

**Files:**
- Modify: `lib/src/renderer.dart:303-313` (add `_lastContent` field + guard)
- Test: `test/perf_hotpath_test.dart`

- [ ] **Step 1: Write the test (uses a StringBuffer-backed sink like the existing renderer tests)**

Append to `test/perf_hotpath_test.dart`. Add these imports at the top of the file:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:dart_tui/src/renderer.dart';
import 'package:dart_tui/src/view.dart';
```

Add a helper sink and group:

```dart
class _CaptureSink implements IOSink {
  final StringBuffer buf = StringBuffer();
  @override
  void write(Object? o) => buf.write(o);
  @override
  void writeln([Object? o = '']) => buf.writeln(o);
  @override
  void writeAll(Iterable objs, [String sep = '']) => buf.writeAll(objs, sep);
  @override
  void writeCharCode(int c) => buf.writeCharCode(c);
  @override
  void add(List<int> data) => buf.write(utf8.decode(data));
  @override
  Future flush() async {}
  @override
  Future close() async {}
  @override
  Future get done => Future.value();
  @override
  void addError(Object e, [StackTrace? st]) {}
  @override
  Future addStream(Stream<List<int>> s) async {}
  @override
  Encoding encoding = utf8;
}

void rendererTests() {
  group('CellRenderer identical-frame guard (Task 3)', () {
    test('second identical render emits no new output', () {
      final sink = _CaptureSink();
      final r = CellRenderer(
        output: sink,
        defaultAltScreen: false,
        defaultHideCursor: false,
      );
      r.render(View(content: 'hello\nworld'));
      final afterFirst = sink.buf.length;
      r.render(View(content: 'hello\nworld'));
      expect(sink.buf.length, afterFirst,
          reason: 'identical content must produce no additional bytes');
    });

    test('changed frame still emits', () {
      final sink = _CaptureSink();
      final r = CellRenderer(
        output: sink,
        defaultAltScreen: false,
        defaultHideCursor: false,
      );
      r.render(View(content: 'hello'));
      final afterFirst = sink.buf.length;
      r.render(View(content: 'jello'));
      expect(sink.buf.length, greaterThan(afterFirst));
    });
  });
}
```

Call `rendererTests();` at the end of `main()`.

- [ ] **Step 2: Run — expect PASS on current code**

Run: `dart test test/perf_hotpath_test.dart -n "CellRenderer identical"`
Expected: PASS (the cell diff already emits nothing for identical grids; this test pins that the CPU-saving guard we add does not change output).

- [ ] **Step 3: Add the guard**

In `lib/src/renderer.dart`, add a field to `CellRenderer` next to `_lastGrid` (line 301):

```dart
  List<List<_Cell>>? _lastGrid;
  String? _lastContent;
```

Replace `render` (lines 303-313):

```dart
  @override
  void render(View view) {
    _applyModes(view);
    if (view.windowTitle.isNotEmpty) {
      _output.write('\x1b]0;${view.windowTitle}\x07');
    }
    if (_lastGrid != null && _lastContent == view.content) {
      return; // identical frame — skip rebuild + diff walk
    }
    final nextGrid = _buildGrid(view.content);
    _diffAndEmit(nextGrid);
    _lastGrid = nextGrid;
    _lastContent = view.content;
    _logSink?.writeln('--- cell frame ---\n${view.content}');
  }
```

Invalidate `_lastContent` everywhere `_lastGrid` is set to `null` (in `clearScreen`, `insertAbove`, `release`, `setAltScreen`, `scroll`). For each `_lastGrid = null;`, add on the next line:

```dart
    _lastContent = null;
```

- [ ] **Step 4: Run tests + analyze**

Run: `dart test test/perf_hotpath_test.dart -n "CellRenderer" && dart test test/cell_renderer_test.dart && dart analyze lib/src/renderer.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/renderer.dart test/perf_hotpath_test.dart
git commit -m "perf(renderer): skip CellRenderer rebuild+diff on identical frames"
```

---

### Task 4: renderer.dart — AnsiRenderer content guard + drop redundant list copy

`AnsiRenderer.render` splits `view.content` on every frame and copies the split result with `List<String>.from`. Guard on the raw content string before splitting, and assign the freshly-owned split list directly.

**Files:**
- Modify: `lib/src/renderer.dart:80-108` (add `_lastContent`, early-return before split, drop copy)
- Test: `test/perf_hotpath_test.dart`

- [ ] **Step 1: Extend the renderer test group**

Append inside `rendererTests()`:

```dart
  group('AnsiRenderer identical-frame guard (Task 4)', () {
    test('second identical render emits no new output', () {
      final sink = _CaptureSink();
      final r = AnsiRenderer(
        output: sink,
        defaultAltScreen: false,
        defaultHideCursor: false,
      );
      r.render(View(content: 'a\nb\nc'));
      final afterFirst = sink.buf.length;
      r.render(View(content: 'a\nb\nc'));
      expect(sink.buf.length, afterFirst);
    });

    test('changed line is re-emitted', () {
      final sink = _CaptureSink();
      final r = AnsiRenderer(
        output: sink,
        defaultAltScreen: false,
        defaultHideCursor: false,
      );
      r.render(View(content: 'a\nb\nc'));
      final afterFirst = sink.buf.length;
      r.render(View(content: 'a\nX\nc'));
      expect(sink.buf.length, greaterThan(afterFirst));
    });
  });
```

- [ ] **Step 2: Run — expect PASS**

Run: `dart test test/perf_hotpath_test.dart -n "AnsiRenderer identical"`
Expected: PASS (AnsiRenderer already short-circuits identical frames via `_linesEqual`; this pins that behavior before the refactor).

- [ ] **Step 3: Add `_lastContent` guard + drop the copy**

In `AnsiRenderer`, add next to `_lastLines` (line 76):

```dart
  List<String> _lastLines = const <String>[];
  String _lastContent = '';
```

In `render` (lines 86-89), replace the split+equality block:

```dart
    if (_hasRenderedFrame && view.content == _lastContent) {
      return;
    }
    final nextLines = view.content.split('\n');
```

Replace line 105 (`_lastLines = List<String>.from(nextLines);`) with a direct assignment (the split output is private and freshly owned):

```dart
    _lastLines = nextLines;
    _lastContent = view.content;
```

In `clearScreen` and `release`, where `_lastLines = const <String>[];` appears, add:

```dart
    _lastContent = '';
```

(and in `setAltScreen`/`scroll`/`insertAbove` where `_hasRenderedFrame = false;` is set, `_lastContent` staleness is harmless because the guard also checks `_hasRenderedFrame`; leaving it is safe.)

- [ ] **Step 4: Run tests + analyze**

Run: `dart test test/perf_hotpath_test.dart -n "AnsiRenderer" && dart test test/renderer_test.dart test/renderer_sync_test.dart && dart analyze lib/src/renderer.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/renderer.dart test/perf_hotpath_test.dart
git commit -m "perf(renderer): guard AnsiRenderer on raw content; drop redundant list copy"
```

---

### Task 5: list.dart — memoize `filteredItems`

`filteredItems` is a getter that re-runs the full fuzzy filter on every call, and `update()`/`view()`/`selected`/`_safeCursor` all call it repeatedly per keystroke. Since the model is immutable, compute it once as a `late final` field.

**Files:**
- Modify: `lib/src/bubbles/list.dart:179-185`
- Test: `test/perf_hotpath_test.dart`

- [ ] **Step 1: Write the memoization test (genuine red→green)**

Append to `main()` in `test/perf_hotpath_test.dart`:

```dart
  group('list filter memoization (Task 5)', () {
    test('filteredItems returns the identical cached list across calls', () {
      final m = ListModel(
        items: [
          ListItem(title: 'apple'),
          ListItem(title: 'banana'),
          ListItem(title: 'apricot'),
        ],
        filter: 'ap',
      );
      expect(identical(m.filteredItems, m.filteredItems), isTrue);
    });

    test('filtering results are unchanged', () {
      final m = ListModel(
        items: [
          ListItem(title: 'apple'),
          ListItem(title: 'banana'),
          ListItem(title: 'apricot'),
        ],
        filter: 'ap',
      );
      expect(m.filteredItems.map((i) => i.title), ['apple', 'apricot']);
    });
  });
```

- [ ] **Step 2: Run — expect the identity test to FAIL**

Run: `dart test test/perf_hotpath_test.dart -n "list filter"`
Expected: `filteredItems returns the identical cached list` FAILS (getter currently returns a new list each call); the results test PASSES.

- [ ] **Step 3: Convert the getter to a memoized `late final` field**

In `lib/src/bubbles/list.dart`, replace the `filteredItems` getter (lines 178-185):

```dart
  /// Items that match the current [filter] query (fuzzy, case-insensitive).
  ///
  /// Memoized: computed once per model instance on first access.
  late final List<ListItem> filteredItems = _computeFilteredItems();

  List<ListItem> _computeFilteredItems() {
    if (filter.isEmpty) return items;
    final q = filter.toLowerCase();
    return items
        .where((item) => _fuzzyMatch(item._filterKey.toLowerCase(), q))
        .toList();
  }
```

- [ ] **Step 4: Run — both pass now**

Run: `dart test test/perf_hotpath_test.dart -n "list filter" && dart test test/list_model_test.dart && dart analyze lib/src/bubbles/list.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/bubbles/list.dart test/perf_hotpath_test.dart
git commit -m "perf(list): memoize filteredItems as late final"
```

---

### Task 6: tree.dart — reuse flattened list when root is unchanged

`_copyWith` always routes through the public constructor, which re-runs `_buildFlatList` (spread-copying `path`/`parentIsLast` per node). Navigation (cursor/scroll changes) leaves `root` untouched, so the flat list can be reused via a private constructor.

**Files:**
- Modify: `lib/src/bubbles/tree.dart:114-122` (add `_withFlat` ctor), `:251-263` (`_copyWith`)
- Test: `test/perf_hotpath_test.dart`

- [ ] **Step 1: Write the behavior test**

Append to `main()`:

```dart
  group('tree flatten reuse (Task 6)', () {
    TreeNode sample() => TreeNode(label: 'root', isExpanded: true, children: [
          TreeNode(label: 'a'),
          TreeNode(label: 'b', isExpanded: true, children: [
            TreeNode(label: 'b1'),
          ]),
        ]);

    test('cursor navigation preserves node count and structure', () {
      final t = TreeModel(root: sample());
      final before = t.nodeCount;
      final (moved, _) = t.update(KeyPressMsg(const TeaKey(code: KeyCode.down)));
      expect((moved as TreeModel).nodeCount, before);
      expect(moved.view().content, t.view().content); // same rows, cursor moved
    });

    test('toggling collapse changes node count', () {
      final t = TreeModel(root: sample());
      final before = t.nodeCount; // root + a + b + b1 = 4
      // move cursor to 'b' (index 2) then collapse
      var m = t;
      m = m.update(KeyPressMsg(const TeaKey(code: KeyCode.down))).$1 as TreeModel;
      m = m.update(KeyPressMsg(const TeaKey(code: KeyCode.down))).$1 as TreeModel;
      m = m.update(KeyPressMsg(const TeaKey(code: KeyCode.left))).$1 as TreeModel;
      expect(m.nodeCount, lessThan(before));
    });
  });
```

(Note: `moved.view().content == t.view().content` holds because cursor highlight styling is present in both but the *same* row is highlighted only if cursor is equal — adjust: after `down`, row 1 is highlighted instead of row 0, so contents differ. Use `nodeCount` equality as the structural invariant and drop the content equality line.)

Use this corrected first test body:

```dart
    test('cursor navigation preserves node count and structure', () {
      final t = TreeModel(root: sample());
      final before = t.nodeCount;
      final (moved, _) = t.update(KeyPressMsg(const TeaKey(code: KeyCode.down)));
      expect((moved as TreeModel).nodeCount, before);
      expect(moved.nodeCount, 4);
    });
```

- [ ] **Step 2: Run — expect PASS on current code**

Run: `dart test test/perf_hotpath_test.dart -n "tree flatten"`
Expected: PASS (behavior baseline).

- [ ] **Step 3: Add `_withFlat` and reuse it in `_copyWith`**

In `lib/src/bubbles/tree.dart`, add a private constructor after the public one (after line 122):

```dart
  TreeModel._withFlat({
    required this.root,
    required this.cursor,
    required this.scrollOffset,
    required this.height,
    required this.styles,
    required this.viewOffsetY,
    required List<_FlatNode> flat,
  }) : _flat = flat;
```

Replace `_copyWith` (lines 251-263) so an unchanged root reuses `_flat`:

```dart
  TreeModel _copyWith({
    TreeNode? root,
    int? cursor,
    int? scrollOffset,
  }) {
    if (root == null) {
      // root unchanged → the flattened list is identical; reuse it.
      return TreeModel._withFlat(
        root: this.root,
        cursor: cursor ?? this.cursor,
        scrollOffset: scrollOffset ?? this.scrollOffset,
        height: height,
        styles: styles,
        viewOffsetY: viewOffsetY,
        flat: _flat,
      );
    }
    return TreeModel(
      root: root,
      cursor: cursor ?? this.cursor,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      height: height,
      styles: styles,
      viewOffsetY: viewOffsetY,
    );
  }
```

- [ ] **Step 4: Run tests + analyze**

Run: `dart test test/perf_hotpath_test.dart -n "tree flatten" && dart test test/tree_test.dart && dart analyze lib/src/bubbles/tree.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/bubbles/tree.dart test/perf_hotpath_test.dart
git commit -m "perf(tree): reuse flattened node list on cursor-only copyWith"
```

---

### Task 7: program.dart — precompute frame budget + monotonic clock in render()

`render()` recomputes `minFrameMicros` (float divide + round) and calls `DateTime.now()` twice per frame. `_fps` is fixed for the run; use a precomputed budget and a monotonic `Stopwatch` instead of wall-clock reads.

**Files:**
- Modify: `lib/src/program.dart:268-282`
- Test: covered by existing `test/program_options_test.dart` (no behavior change); no new assertion needed, but verify the suite still passes.

- [ ] **Step 1: Confirm the existing program tests pass (baseline)**

Run: `dart test test/program_options_test.dart test/program_requests_test.dart`
Expected: PASS.

- [ ] **Step 2: Precompute the budget and switch to a Stopwatch**

In `lib/src/program.dart`, inside `_runCore`, just before the `render` closure (before line 268 `var lastRenderMicros = 0;`), add:

```dart
    final minFrameMicros = _fps > 0 ? (1000000 / _fps).round() : 0;
    final frameClock = Stopwatch()..start();
```

Replace the `render` closure (lines 268-282):

```dart
    var lastRenderMicros = -1;
    Future<void> render(View v) async {
      final nowMicros = frameClock.elapsedMicroseconds;
      if (lastRenderMicros >= 0 && minFrameMicros > 0) {
        final delta = nowMicros - lastRenderMicros;
        if (delta < minFrameMicros) {
          await Future<void>.delayed(
            Duration(microseconds: minFrameMicros - delta),
          );
        }
      }
      _renderer?.render(v);
      lastRenderMicros = frameClock.elapsedMicroseconds;
    }
```

- [ ] **Step 3: Run the program suite + analyze**

Run: `dart test test/program_options_test.dart test/program_requests_test.dart && dart analyze lib/src/program.dart`
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/src/program.dart
git commit -m "perf(program): precompute frame budget, use monotonic Stopwatch in render()"
```

---

### Task 8: Full-suite verification

- [ ] **Step 1: Run the entire suite, analyzer, and formatter**

Run: `dart analyze && dart format --output=none --set-exit-if-changed . && dart test`
Expected: analyzer clean, formatter reports no changes, all tests PASS (existing count + the new `perf_hotpath_test.dart` cases).

- [ ] **Step 2: Run the PTY smoke test to confirm interactive examples still render**

Run: `python3 tool/pty_examples_smoke.py`
Expected: PASS (exit 0).

- [ ] **Step 3: Commit any formatting fixups if needed**

```bash
git add -A
git commit -m "chore: formatting after perf hot-path pass" || echo "nothing to format"
```

---

## Deferred / Phase 2 (verified real, but fiddlier or lower-value — not in this plan)

Implement these only if profiling of a real workload justifies the added risk:

- **`_buildGrid` / `_truncateVisible` single-iterator walk** (renderer.dart:414, style.dart:1130) — eliminate `substring(i)` per grapheme with one `CharacterRange`. Real, but must correctly handle combining marks (do **not** fall back to code-units on `<0x80`), so it needs careful tests. Medium value.
- **Input decoder head-index buffer** (input_decoder.dart:111) — replace `removeRange(0,n)` with a `_start` index; the true quadratic is the paste inner loop (line 29 drains byte-by-byte). Broad refactor touching all consume sites; medium value, medium risk.
- **TextAreaModel line storage** (text_area.dart:38) — store `List<String>` instead of splitting/joining the whole value each keypress. Real but niche (documents are small, `maxHeight` default 10); low realized value.
- **SequenceMsg off the drain loop** (program.dart:398) — run sequences as a detached task so slow commands don't block input. Note the naive closure loses switch-promotion of `msg`; bind `final cmds = msg.cmds;` first. Medium value; changes async ordering, so needs dedicated tests.

## Refuted findings (do NOT implement — verified as non-issues)

`unawaited(runCmd(null))` microtask guard (empirically zero microtasks), `runCmd` FutureOr hop (cold + not correctness-preserving), StreamController removal (cold external path), `waitForActivity` Completer churn (negligible), batched-drain starvation (timers are macrotasks), first-frame render bypass (cold), lone-escape timer (only allocated when pending), **tick coalescing (UNSAFE — drops spinner/cursor frames)**, TableModel width memo (~10µs), decoder prefix-matcher dispatch (cold).

---

## Self-Review

- **Spec coverage:** Tasks 1-7 implement every confirmed-worthwhile perf finding (`_visibleWidth`/`stripAnsi`, viewport re-wrap, CellRenderer guard, AnsiRenderer guard+copy, list memo, tree flatten, render-throttle cleanup). Deferred/refuted findings are explicitly listed so nothing is silently dropped. ✅
- **Placeholder scan:** every code step contains the actual before/after code and exact run commands. ✅
- **Type consistency:** new symbols — `_graphemeWidth` (style.dart), `ViewportModel._withWrapped`, `CellRenderer._lastContent`, `AnsiRenderer._lastContent`, `ListModel._computeFilteredItems`, `TreeModel._withFlat` — are each defined and referenced within the same task. Renderer test helper `_CaptureSink` and `rendererTests()` are defined once and reused. ✅
- **Known caveat carried into the plan:** Task 6 Step 1 corrects an over-eager assertion (cursor highlight differs after navigation) inline. ✅
