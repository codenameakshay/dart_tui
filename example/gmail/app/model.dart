import 'package:dart_tui/dart_tui.dart';

import '../gmail/gws_source.dart';
import '../gmail/models.dart';
import '../gmail/source.dart';
import '../util/frame.dart';
import '../util/theme.dart';
import 'messages.dart';
import 'tabs.dart';
import 'views/header.dart';
import 'views/message_list.dart';
import 'views/message_view.dart';
import 'views/status_bar.dart';

enum FocusPane { list, viewport, search }

const int pageSize = 50;

final class AppModel extends TeaModel {
  AppModel({
    GmailSource? source,
    this.width = 120,
    this.height = 36,
    this.query = 'in:inbox',
    this.cache = const [],
    this.pageIndex = 0,
    this.cursor = 0,
    this.loadingList = true,
    this.listError,
    this.openMessage,
    this.loadingBody = false,
    this.bodyError,
    this.bodyCache = const {},
    this.focus = FocusPane.list,
    this.spinnerIndex = 0,
    TextInputModel? search,
    ViewportModel? viewport,
    SpinnerModel? spinner,
  })  : source = source ?? const GwsGmailSource(),
        search = search ??
            TextInputModel(
              placeholder:
                  'Gmail query — e.g. from:alice is:unread newer_than:7d',
              charLimit: 160,
              focused: false,
            ),
        viewport =
            viewport ?? ViewportModel(content: '', width: 60, height: 20),
        spinner = spinner ?? SpinnerModel();

  final GmailSource source;
  final int width;
  final int height;

  final String query;
  final List<MessageSummary> cache;
  final int pageIndex;
  final int cursor;

  final bool loadingList;
  final String? listError;

  final Message? openMessage;
  final bool loadingBody;
  final String? bodyError;
  final Map<String, Message> bodyCache;

  final FocusPane focus;
  final int spinnerIndex;
  final TextInputModel search;
  final ViewportModel viewport;
  final SpinnerModel spinner;

  // ── Layout ────────────────────────────────────────────────────────────────
  int get _headerH => 2;
  int get _statusH => 1;
  int get bodyAreaH => (height - _headerH - _statusH).clamp(6, 9999);
  int get listWidth => (width * 0.42).round().clamp(36, 60);
  int get rightWidth => (width - listWidth).clamp(30, 9999);

  // ── Derived data ──────────────────────────────────────────────────────────
  List<MessageSummary> get currentPage {
    final start = pageIndex * pageSize;
    if (start >= cache.length) return const [];
    final end = (start + pageSize).clamp(0, cache.length);
    return cache.sublist(start, end);
  }

  MessageSummary? get selectedSummary {
    final page = currentPage;
    if (page.isEmpty) return null;
    return page[cursor.clamp(0, page.length - 1)];
  }

  int get activeTabIndex => tabIndexForQuery(query);

  AppModel copyWith({
    int? width,
    int? height,
    String? query,
    List<MessageSummary>? cache,
    int? pageIndex,
    int? cursor,
    bool? loadingList,
    Object? listError = _sentinel,
    Object? openMessage = _sentinel,
    bool? loadingBody,
    Object? bodyError = _sentinel,
    Map<String, Message>? bodyCache,
    FocusPane? focus,
    int? spinnerIndex,
    TextInputModel? search,
    ViewportModel? viewport,
    SpinnerModel? spinner,
  }) =>
      AppModel(
        source: source,
        width: width ?? this.width,
        height: height ?? this.height,
        query: query ?? this.query,
        cache: cache ?? this.cache,
        pageIndex: pageIndex ?? this.pageIndex,
        cursor: cursor ?? this.cursor,
        loadingList: loadingList ?? this.loadingList,
        listError: identical(listError, _sentinel)
            ? this.listError
            : listError as String?,
        openMessage: identical(openMessage, _sentinel)
            ? this.openMessage
            : openMessage as Message?,
        loadingBody: loadingBody ?? this.loadingBody,
        bodyError: identical(bodyError, _sentinel)
            ? this.bodyError
            : bodyError as String?,
        bodyCache: bodyCache ?? this.bodyCache,
        focus: focus ?? this.focus,
        spinnerIndex: spinnerIndex ?? this.spinnerIndex,
        search: search ?? this.search,
        viewport: viewport ?? this.viewport,
        spinner: spinner ?? this.spinner,
      );

  // ── Init / update ─────────────────────────────────────────────────────────
  @override
  Cmd? init() => () async {
        await Future<void>.delayed(Duration.zero);
        return _SearchTrigger(query, pageSize);
      };

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg) {
      return (_resize(msg.width, msg.height), null);
    }

    if (msg is TickMsg) {
      final (nextSpinner, _) = spinner.update(msg);
      return (copyWith(spinner: nextSpinner as SpinnerModel), null);
    }

    if (msg is _SearchTrigger) {
      return (
        copyWith(loadingList: true, listError: null),
        _searchCmd(msg.query, msg.max),
      );
    }

    if (msg is MessagesLoaded) {
      final nextCache = msg.messages;
      final nextPageIndex = msg.targetPage ?? pageIndex;
      final start = nextPageIndex * pageSize;
      final pageLen = (nextCache.length - start).clamp(0, pageSize);
      final nextCursor = (msg.targetPage != null)
          ? 0
          : cursor.clamp(0, pageLen == 0 ? 0 : pageLen - 1);
      final next = copyWith(
        query: msg.query,
        cache: nextCache,
        pageIndex: nextPageIndex,
        loadingList: false,
        listError: null,
        cursor: nextCursor,
      );
      return (next, next._maybeLoadBodyCmd());
    }

    if (msg is MessageBodyLoaded) {
      final nextBodyCache = Map<String, Message>.from(bodyCache)
        ..[msg.requestedId] = msg.message;
      if (msg.requestedId != selectedSummary?.id) {
        return (copyWith(bodyCache: nextBodyCache), null);
      }
      return (
        copyWith(
          openMessage: msg.message,
          loadingBody: false,
          bodyError: null,
          bodyCache: nextBodyCache,
          viewport: _makeViewport(msg.message.bodyText),
        ),
        null,
      );
    }

    if (msg is LoadFailed) {
      if (msg.duringBody) {
        if (msg.requestedId == selectedSummary?.id) {
          return (copyWith(loadingBody: false, bodyError: msg.error), null);
        }
        return (this, null);
      }
      return (copyWith(loadingList: false, listError: msg.error), null);
    }

    if (msg is MouseMsg) {
      return _handleMouse(msg);
    }

    if (msg is KeyMsg) {
      return _handleKey(msg);
    }

    return (this, null);
  }

  AppModel _resize(int w, int h) {
    final next = copyWith(width: w, height: h);
    final newVp = ViewportModel(
      content: viewport.content,
      width: (next.rightWidth - 4).clamp(10, 9999),
      height: (next.bodyAreaH - 10).clamp(3, 9999),
      yOffset: viewport.yOffset,
      softWrap: true,
    );
    return next.copyWith(viewport: newVp);
  }

  // ── Input routing ─────────────────────────────────────────────────────────
  (Model, Cmd?) _handleKey(KeyMsg msg) {
    if (focus == FocusPane.search) {
      switch (msg.key) {
        case 'esc':
          return (
            copyWith(
              focus: FocusPane.list,
              search: search.copyWith(focused: false, value: '', cursorPos: 0),
            ),
            null,
          );
        case 'enter':
          final q = search.value.trim();
          if (q.isEmpty) return (this, null);
          final next = copyWith(
            query: q,
            cache: const [],
            pageIndex: 0,
            cursor: 0,
            loadingList: true,
            listError: null,
            openMessage: null,
            bodyError: null,
            focus: FocusPane.list,
            search: search.copyWith(focused: false, value: '', cursorPos: 0),
          );
          return (next, _searchCmd(q, pageSize));
        case 'ctrl+c':
          return (this, () => quit());
      }
      final (nextInput, cmd) = search.update(msg);
      return (copyWith(search: nextInput as TextInputModel), cmd);
    }

    switch (msg.key) {
      case 'q':
      case 'ctrl+c':
        return (this, () => quit());
      case '/':
        return (
          copyWith(
            focus: FocusPane.search,
            search: search.copyWith(focused: true),
          ),
          null,
        );
      case 'esc':
        // Escape from a search result back to Inbox tab.
        if (activeTabIndex == -1 && !loadingList) {
          return _switchTab(0);
        }
        return (this, null);
      case 'tab':
        return (
          copyWith(
            focus:
                focus == FocusPane.list ? FocusPane.viewport : FocusPane.list,
          ),
          null,
        );
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
        final idx = int.parse(msg.key) - 1;
        if (idx < kTabs.length) return _switchTab(idx);
        return (this, null);
      case 'h':
      case 'shift+tab':
        final cur = activeTabIndex < 0 ? 0 : activeTabIndex;
        return _switchTab((cur - 1).clamp(0, kTabs.length - 1));
      case 'l':
        final cur = activeTabIndex < 0 ? 0 : activeTabIndex;
        return _switchTab((cur + 1).clamp(0, kTabs.length - 1));
      case ']':
        return _nextPage();
      case '[':
        return _prevPage();
      case 'r':
        if (listError != null) {
          return (
            copyWith(loadingList: true, listError: null),
            _searchCmd(query, (pageIndex + 1) * pageSize),
          );
        }
        if (bodyError != null && selectedSummary != null) {
          final id = selectedSummary!.id;
          return (
            copyWith(loadingBody: true, bodyError: null),
            _readCmd(id),
          );
        }
        return (this, null);
    }

    if (focus == FocusPane.list) {
      return _handleListKey(msg);
    }

    final (nextVp, cmd) = viewport.update(msg);
    return (copyWith(viewport: nextVp as ViewportModel), cmd);
  }

  (Model, Cmd?) _handleListKey(KeyMsg msg) {
    final page = currentPage;
    if (page.isEmpty) return (this, null);
    int newCursor = cursor;
    switch (msg.key) {
      case 'down':
      case 'j':
        newCursor = (cursor + 1).clamp(0, page.length - 1);
      case 'up':
      case 'k':
        newCursor = (cursor - 1).clamp(0, page.length - 1);
      case 'pgdown':
      case 'ctrl+f':
        newCursor = (cursor + 10).clamp(0, page.length - 1);
      case 'pgup':
      case 'ctrl+b':
        newCursor = (cursor - 10).clamp(0, page.length - 1);
      case 'home':
      case 'g':
        newCursor = 0;
      case 'end':
      case 'G':
        newCursor = page.length - 1;
      case 'enter':
        // Force focus to viewport.
        return (copyWith(focus: FocusPane.viewport), null);
      default:
        return (this, null);
    }
    if (newCursor == cursor) return (this, null);
    final next = copyWith(cursor: newCursor);
    return (next, next._maybeLoadBodyCmd());
  }

  (Model, Cmd?) _handleMouse(MouseMsg msg) {
    final m = msg.mouse;
    // Wheel scroll: forward to whichever pane the cursor is over.
    if (msg is MouseWheelMsg) {
      if (_pointInRightPane(m.x, m.y)) {
        final (v, _) = viewport.update(
          KeyPressMsg(TeaKey(
            code: KeyCode.rune,
            text: m.button == MouseButton.wheelUp ? 'k' : 'j',
          )),
        );
        return (copyWith(viewport: v as ViewportModel), null);
      }
      // List wheel
      final page = currentPage;
      if (page.isEmpty) return (this, null);
      final delta = m.button == MouseButton.wheelUp ? -1 : 1;
      final newCursor = (cursor + delta).clamp(0, page.length - 1);
      if (newCursor == cursor) return (this, null);
      final next = copyWith(cursor: newCursor);
      return (next, next._maybeLoadBodyCmd());
    }

    if (msg is MouseClickMsg && m.button == MouseButton.left) {
      // Header tab hit-test (row 0).
      if (m.y == 0) {
        final bounds = <(int, int, int)>[];
        renderHeader(
          width: width,
          activeTab: activeTabIndex,
          customQuery: query,
          outBounds: bounds,
        );
        for (final b in bounds) {
          if (m.x >= b.$1 && m.x < b.$2) {
            if (b.$3 >= 0 && b.$3 < kTabs.length) return _switchTab(b.$3);
          }
        }
        return (this, null);
      }
      // List pane rows.
      if (m.x < listWidth && _pointInBody(m.y)) {
        final localY = m.y - _headerH - 1; // minus frame top
        final page = currentPage;
        if (localY >= 0 && localY < page.length) {
          if (localY == cursor) {
            // Second click = focus viewport
            return (copyWith(focus: FocusPane.viewport), null);
          }
          final next = copyWith(cursor: localY, focus: FocusPane.list);
          return (next, next._maybeLoadBodyCmd());
        }
      }
      if (m.x >= listWidth && _pointInBody(m.y)) {
        return (copyWith(focus: FocusPane.viewport), null);
      }
    }

    return (this, null);
  }

  bool _pointInBody(int y) => y >= _headerH && y < _headerH + bodyAreaH;
  bool _pointInRightPane(int x, int y) => _pointInBody(y) && x >= listWidth;

  // ── Tab + pagination helpers ──────────────────────────────────────────────
  (Model, Cmd?) _switchTab(int idx) {
    final t = kTabs[idx.clamp(0, kTabs.length - 1)];
    if (t.query == query && !loadingList) return (this, null);
    final next = copyWith(
      query: t.query,
      cache: const [],
      pageIndex: 0,
      cursor: 0,
      loadingList: true,
      listError: null,
      openMessage: null,
      bodyError: null,
      focus: FocusPane.list,
    );
    return (next, _searchCmd(t.query, pageSize));
  }

  (Model, Cmd?) _nextPage() {
    final needed = (pageIndex + 2) * pageSize;
    if (cache.length >= needed ||
        (cache.length % pageSize != 0 &&
            cache.length >= (pageIndex + 1) * pageSize + 1)) {
      if ((pageIndex + 1) * pageSize >= cache.length) return (this, null);
      final next = copyWith(pageIndex: pageIndex + 1, cursor: 0);
      return (next, next._maybeLoadBodyCmd());
    }
    return (
      copyWith(loadingList: true, listError: null),
      _searchCmd(query, needed, targetPage: pageIndex + 1),
    );
  }

  (Model, Cmd?) _prevPage() {
    if (pageIndex == 0) return (this, null);
    final next = copyWith(pageIndex: pageIndex - 1, cursor: 0);
    return (next, next._maybeLoadBodyCmd());
  }

  Cmd? _maybeLoadBodyCmd() {
    final sel = selectedSummary;
    if (sel == null) return null;
    final cached = bodyCache[sel.id];
    if (cached != null) {
      return () async => MessageBodyLoaded(sel.id, cached);
    }
    return _readCmd(sel.id);
  }

  Cmd _searchCmd(String q, int max, {int? targetPage}) {
    final src = source;
    return () async {
      try {
        final results = await src.search(q, max: max);
        return MessagesLoaded(q, results, targetPage: targetPage);
      } catch (e) {
        return LoadFailed(e.toString());
      }
    };
  }

  Cmd _readCmd(String id) {
    final src = source;
    return () async {
      try {
        final m = await src.read(id);
        return MessageBodyLoaded(id, m);
      } catch (e) {
        return LoadFailed(e.toString(), duringBody: true, requestedId: id);
      }
    };
  }

  ViewportModel _makeViewport(String body) => ViewportModel(
        content: _stripNoise(body),
        width: (rightWidth - 4).clamp(10, 9999),
        height: (bodyAreaH - 10).clamp(3, 9999),
        softWrap: true,
      );

  static String _stripNoise(String s) =>
      s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // ── View ──────────────────────────────────────────────────────────────────
  @override
  View view() {
    final bounds = <(int, int, int)>[];
    final header = renderHeader(
      width: width,
      activeTab: activeTabIndex,
      customQuery: query,
      outBounds: bounds,
    );

    final frameH = bodyAreaH;
    final leftRowBounds = <RowBound>[];
    final spinnerFrames = spinner.frames;
    final spinnerFrame = spinnerFrames[spinner.index % spinnerFrames.length];

    final listBody = renderMessageList(
      items: currentPage,
      cursor: cursor.clamp(0, currentPage.isEmpty ? 0 : currentPage.length - 1),
      width: listWidth - 2,
      height: frameH - 2,
      outBounds: leftRowBounds,
      loading: loadingList,
      loadingFrame: spinnerFrame,
    );
    final leftBadge = loadingList
        ? '$spinnerFrame loading'
        : listError != null
            ? '$iError error'
            : '${cache.length} · p${pageIndex + 1}';
    final leftFrame = frame(
      body: listBody,
      width: listWidth,
      height: frameH,
      title: _listTitle(),
      badge: leftBadge,
      focused: focus == FocusPane.list,
    );

    final rightBody = renderMessageView(
      width: rightWidth - 2,
      height: frameH - 2,
      loading: loadingBody,
      error: bodyError,
      message: openMessage,
      viewport: _liveViewport(),
      loadingFrame: spinnerFrame,
    );
    final rightBadge = openMessage != null ? _scrollBadge() : null;
    final rightFrame = frame(
      body: rightBody,
      width: rightWidth,
      height: frameH,
      title: openMessage?.subject ?? 'Message',
      badge: rightBadge,
      focused: focus == FocusPane.viewport,
    );

    final body = _joinHorizontal(leftFrame, rightFrame);

    final hints = <({String keys, String label})>[
      (keys: 'h/l', label: 'tabs'),
      (keys: 'j/k', label: 'move'),
      (keys: '/', label: 'search'),
      (keys: ']/[', label: 'page'),
      (keys: 'tab', label: 'focus'),
      (keys: 'q', label: 'quit'),
    ];

    final bar = renderStatusBar(
      width: width,
      query: query,
      totalShown: cache.length,
      pageIndex: pageIndex,
      loading: loadingList,
      error: listError,
      searching: focus == FocusPane.search,
      searchInputView: search.view().content,
      spinnerFrame: spinnerFrame,
      hints: hints,
    );

    final v = View(
      content: '$header\n$body\n$bar',
      mouseMode: MouseMode.cellMotion,
      altScreen: true,
    );
    return v;
  }

  String _listTitle() {
    final idx = activeTabIndex;
    if (idx >= 0) return kTabs[idx].label;
    return 'Search: $query';
  }

  String? _scrollBadge() {
    if (viewport.totalLines == 0) return null;
    final pct = (viewport.scrollPercent * 100).clamp(0, 100).round();
    return '$pct%';
  }

  ViewportModel _liveViewport() {
    final w = (rightWidth - 4).clamp(10, 9999);
    final h = (bodyAreaH - 10).clamp(3, 9999);
    if (viewport.width == w && viewport.height == h) return viewport;
    return ViewportModel(
      content: viewport.content,
      width: w,
      height: h,
      yOffset: viewport.yOffset,
      softWrap: true,
    );
  }
}

String _joinHorizontal(String left, String right) {
  final l = left.split('\n');
  final r = right.split('\n');
  final h = l.length > r.length ? l.length : r.length;
  final out = <String>[];
  for (var i = 0; i < h; i++) {
    final ll = i < l.length ? l[i] : '';
    final rr = i < r.length ? r[i] : '';
    out.add('$ll$rr');
  }
  return out.join('\n');
}

class _SearchTrigger extends Msg {
  _SearchTrigger(this.query, this.max);
  final String query;
  final int max;
}

const Object _sentinel = Object();
