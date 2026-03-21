// Comprehensive interactive demo of dart_tui APIs.
// Run from package root:
//   fvm dart run example/showcase.dart

import 'package:dart_tui/dart_tui.dart';

import 'shopping_list.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(
      altScreen: true,
      tickInterval: Duration(milliseconds: 80),
    ),
  ).run(ShowcaseModel());
}

final class ShowcaseModel extends TeaModel {
  ShowcaseModel({
    this.screen = ShowcaseScreen.menu,
    this.menuCursor = 0,
    this.child,
    this.width = 0,
    this.height = 0,
  });

  final ShowcaseScreen screen;
  final int menuCursor;
  final TeaModel? child;
  final int width;
  final int height;

  static const _menuItems = <String>[
    'Shopping list (Bubble Tea tutorial port)',
    'Spinner (TickMsg animation)',
    'Progress bar (TickMsg animation)',
    'Text input',
    'Select list',
    'Paginator',
    'Help component',
    'Style / border / padding demo',
    'Command + event demo',
    'Prompts API usage',
    'Package API reference',
  ];

  ShowcaseModel _copyWith({
    ShowcaseScreen? screen,
    int? menuCursor,
    TeaModel? child,
    int? width,
    int? height,
    bool clearChild = false,
  }) {
    return ShowcaseModel(
      screen: screen ?? this.screen,
      menuCursor: menuCursor ?? this.menuCursor,
      child: clearChild ? null : (child ?? this.child),
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg) {
      return (_copyWith(width: msg.width, height: msg.height), null);
    }

    if (screen == ShowcaseScreen.menu) {
      return _updateMenu(msg);
    }

    if (msg is KeyMsg) {
      final key = msg.key;
      if (key == 'esc' || key == 'b' || key == 'q' || key == 'ctrl+c') {
        return (
          _copyWith(screen: ShowcaseScreen.menu, clearChild: true),
          null,
        );
      }
    }

    final c = child;
    if (c == null) {
      if (_isStaticScreen(screen)) return (_copyWith(), null);
      return (_copyWith(screen: ShowcaseScreen.menu), null);
    }

    final (nextChild, cmd) = c.update(msg);
    return (_copyWith(child: nextChild), cmd);
  }

  (TeaModel, Cmd?) _updateMenu(Msg msg) {
    if (msg is TickMsg) return (_copyWith(), null);
    if (msg is! KeyMsg) return (_copyWith(), null);

    switch (msg.key) {
      case 'ctrl+c':
      case 'q':
        return (_copyWith(), () => quit());
      case 'up':
      case 'k':
        final next = menuCursor > 0 ? menuCursor - 1 : 0;
        return (_copyWith(menuCursor: next), null);
      case 'down':
      case 'j':
        final next = menuCursor < _menuItems.length - 1
            ? menuCursor + 1
            : _menuItems.length - 1;
        return (_copyWith(menuCursor: next), null);
      case 'enter':
        return _openDemo(menuCursor);
      default:
        return (_copyWith(), null);
    }
  }

  (TeaModel, Cmd?) _openDemo(int index) {
    switch (index) {
      case 0:
        return (
          _copyWith(
            screen: ShowcaseScreen.shopping,
            child: ShoppingModel(
              choices: const ['Buy carrots', 'Buy celery', 'Buy kohlrabi'],
            ),
          ),
          null,
        );
      case 1:
        return (
          _copyWith(
            screen: ShowcaseScreen.spinner,
            child: SpinnerModel(
              prefix: TuiStyle.wrap('Working ', open: TuiStyle.fg256(39)),
              suffix: TuiStyle.wrap(' (spinner)', open: TuiStyle.dim),
            ),
          ),
          null,
        );
      case 2:
        return (
          _copyWith(
            screen: ShowcaseScreen.progress,
            child: ProgressDemoModel(),
          ),
          null,
        );
      case 3:
        return (
          _copyWith(
            screen: ShowcaseScreen.textInput,
            child: TextInputModel(
              label: TuiStyle.wrap('name>', open: TuiStyle.bold),
              placeholder: 'type here',
            ),
          ),
          null,
        );
      case 4:
        return (
          _copyWith(
            screen: ShowcaseScreen.selectList,
            child: SelectListModel(
              title: TuiStyle.wrap(
                'Pick a flavor',
                open: '${TuiStyle.bold}${TuiStyle.fg256(208)}',
              ),
              items: const ['Vanilla', 'Chocolate', 'Mint', 'Coffee'],
            ),
          ),
          null,
        );
      case 5:
        return (
          _copyWith(
            screen: ShowcaseScreen.paginator,
            child: PaginatorModel(page: 0, totalPages: 8),
          ),
          null,
        );
      case 6:
        return (
          _copyWith(
            screen: ShowcaseScreen.help,
            child: HelpModel(
              showBorder: true,
              entries: const [
                (key: 'q', description: 'Quit current demo'),
                (key: 'b', description: 'Back to menu'),
                (key: '↑/↓', description: 'Navigate'),
                (key: 'Enter', description: 'Select'),
              ],
            ),
          ),
          null,
        );
      case 7:
        return (_copyWith(screen: ShowcaseScreen.style), null);
      case 8:
        return (
          _copyWith(
            screen: ShowcaseScreen.commandEvents,
            child: CommandEventsModel(),
          ),
          null,
        );
      case 9:
        return (_copyWith(screen: ShowcaseScreen.prompts), null);
      case 10:
        return (_copyWith(screen: ShowcaseScreen.apiSummary), null);
      default:
        return (_copyWith(), null);
    }
  }

  @override
  View view() {
    switch (screen) {
      case ShowcaseScreen.menu:
        return newView(_menuView());
      case ShowcaseScreen.style:
        return newView(_styleView());
      case ShowcaseScreen.prompts:
        return newView(_promptsView());
      case ShowcaseScreen.apiSummary:
        return newView(_apiSummaryView());
      case ShowcaseScreen.shopping:
      case ShowcaseScreen.spinner:
      case ShowcaseScreen.progress:
      case ShowcaseScreen.textInput:
      case ShowcaseScreen.selectList:
      case ShowcaseScreen.paginator:
      case ShowcaseScreen.help:
      case ShowcaseScreen.commandEvents:
        final body = child?.view().content ?? '(no model)';
        return newView(_wrapChild(body));
    }
  }

  String _menuView() {
    final b = StringBuffer()
      ..writeln(
        TuiStyle.wrap(
          'dart_tui — full showcase',
          open: '${TuiStyle.bold}${TuiStyle.fg256(141)}',
        ),
      )
      ..writeln(
        '${TuiStyle.dim}Window: ${width}x$height · Enter opens demo · q exits${TuiStyle.reset}',
      )
      ..writeln();
    for (var i = 0; i < _menuItems.length; i++) {
      final mark = i == menuCursor ? '>' : ' ';
      b.writeln('$mark ${_menuItems[i]}');
    }
    b
      ..writeln()
      ..writeln(
        '${TuiStyle.dim}↑/↓ or j/k navigate · Enter open · q quit${TuiStyle.reset}',
      );
    return b.toString();
  }

  String _styleView() {
    final sample = const Style()
        .foregroundColor256(39)
        .bold()
        .withPadding(const EdgeInsets.all(1))
        .withBorder(Border.rounded)
        .render(
            'Style().foregroundColor256(39).bold()\\n.withPadding(1).withBorder(rounded)');

    return _wrapChild('''
${TuiStyle.bold}Style API${TuiStyle.reset}

$sample

Compatibility helpers:
  ${TuiStyle.wrap('TuiStyle.fg256(214)', open: TuiStyle.fg256(214))}
  ${TuiStyle.wrap('TuiStyle.fgRgb(255,80,80)', open: TuiStyle.fgRgb(255, 80, 80))}
  ${TuiStyle.wrap('TuiStyle.bold', open: TuiStyle.bold)}
  ${TuiStyle.wrap('TuiStyle.dim', open: TuiStyle.dim)}
''');
  }

  String _promptsView() {
    return _wrapChild('''
${TuiStyle.bold}Prompts API${TuiStyle.reset}

  • promptSelect(choices)  → Future<String?>
  • promptConfirm(text)    → Future<bool?>
  • promptInput(label)     → Future<String?>

Run:
  fvm dart run example/prompts_chain.dart

Prompts run their own Program instances, so this showcase keeps them as
documentation to avoid nested terminal sessions.
''');
  }

  String _apiSummaryView() {
    return _wrapChild('''
${TuiStyle.bold}Package API Summary${TuiStyle.reset}

Core:
  • Model / TeaModel alias
  • Msg types: KeyPressMsg, WindowSizeMsg, TickMsg, PasteMsg, FocusMsg, ...
  • Cmd helpers: batch, sequence, tick, every, raw, request* commands
  • Program APIs: run, runForResult, send, quit, kill, wait,
    releaseTerminal, restoreTerminal, println, printf

Bubbles:
  • SpinnerModel, ProgressModel, TextInputModel, SelectListModel
  • PaginatorModel, HelpModel

Style:
  • Style() with color/emphasis/padding/margin/border
  • TuiStyle legacy helper wrappers
''');
  }

  String _wrapChild(String body) {
    return '''
${TuiStyle.bold}${TuiStyle.fg256(214)}dart_tui${TuiStyle.reset} ${TuiStyle.dim}showcase${TuiStyle.reset}
${TuiStyle.dim}────────────────────────────────────────${TuiStyle.reset}

$body

${TuiStyle.dim}b / Esc / q / ctrl+c → back to menu${TuiStyle.reset}
''';
  }
}

bool _isStaticScreen(ShowcaseScreen s) {
  return s == ShowcaseScreen.style ||
      s == ShowcaseScreen.prompts ||
      s == ShowcaseScreen.apiSummary;
}

enum ShowcaseScreen {
  menu,
  shopping,
  spinner,
  progress,
  textInput,
  selectList,
  paginator,
  help,
  style,
  commandEvents,
  prompts,
  apiSummary,
}

final class ProgressDemoModel extends TeaModel {
  ProgressDemoModel({this.t = 0});
  final double t;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      var next = t + 0.02;
      if (next > 1.0) next = 0;
      return (ProgressDemoModel(t: next), null);
    }
    return (this, null);
  }

  @override
  View view() {
    return ProgressModel(
      fraction: t,
      width: 48,
      label: TuiStyle.wrap('download', open: TuiStyle.fg256(109)),
    ).view();
  }
}

final class CommandEventsModel extends TeaModel {
  CommandEventsModel({
    this.last = const <String>[],
    this.counter = 0,
  });

  final List<String> last;
  final int counter;

  CommandEventsModel _next(String line) {
    final updated = [...last, line];
    final trimmed =
        updated.length > 12 ? updated.sublist(updated.length - 12) : updated;
    return CommandEventsModel(last: trimmed, counter: counter + 1);
  }

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'p':
          return (
            _next('Pressed p → Println command dispatched'),
            println('showcase: println from command'),
          );
        case 'r':
          return (
            _next('Pressed r → raw command dispatched'),
            raw('\x1b[5n'),
          );
        case 'w':
          return (
            _next('Pressed w → requestWindowSize'),
            () => requestWindowSize()
          );
        case 'f':
          return (
            _next('Pressed f → requestForegroundColor'),
            () => requestForegroundColor()
          );
        case 'c':
          return (
            _next('Pressed c → requestCapability("Tc")'),
            requestCapability('Tc'),
          );
        default:
          return (_next('Key: ${msg.key}'), null);
      }
    }
    if (msg is WindowSizeMsg) {
      return (_next('WindowSizeMsg: ${msg.width}x${msg.height}'), null);
    }
    if (msg is FocusMsg) {
      return (_next('FocusMsg'), null);
    }
    if (msg is BlurMsg) {
      return (_next('BlurMsg'), null);
    }
    if (msg is PasteStartMsg) {
      return (_next('PasteStartMsg'), null);
    }
    if (msg is PasteMsg) {
      return (_next('PasteMsg: "${msg.content}"'), null);
    }
    if (msg is PasteEndMsg) {
      return (_next('PasteEndMsg'), null);
    }
    if (msg is CapabilityMsg) {
      return (_next('CapabilityMsg: ${msg.content}'), null);
    }
    if (msg is ForegroundColorMsg) {
      return (
        _next('ForegroundColorMsg: 0x${msg.rgb.toRadixString(16)}'),
        null
      );
    }
    return (this, null);
  }

  @override
  View view() {
    final b = StringBuffer()
      ..writeln('${TuiStyle.bold}Command + Event Demo${TuiStyle.reset}')
      ..writeln('Press keys:')
      ..writeln('  p = println')
      ..writeln('  r = raw')
      ..writeln('  w = requestWindowSize')
      ..writeln('  f = requestForegroundColor')
      ..writeln('  c = requestCapability("Tc")')
      ..writeln()
      ..writeln('Recent events:')
      ..writeln('--------------');

    for (final line in last) {
      b.writeln(line);
    }
    return newView(b.toString());
  }
}
