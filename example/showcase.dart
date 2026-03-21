// Interactive demo of dart_tui components. Run from package root:
//   dart run example/showcase.dart

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

/// Hub that switches between demos. Keys: menu ↑/↓ Enter; sub-screens b/Esc/q/ctrl+c → menu; menu q → exit.
final class ShowcaseModel extends TeaModel {
  ShowcaseModel({
    this.screen = ShowcaseScreen.menu,
    this.menuCursor = 0,
    this.child,
    this.quitting = false,
  });

  final ShowcaseScreen screen;
  final int menuCursor;
  final TeaModel? child;
  final bool quitting;

  static const _menuItems = <String>[
    'Shopping list (Bubble Tea tutorial)',
    'Spinner (TickMsg animation)',
    'Progress bar (TickMsg animation)',
    'Text input',
    'Select list',
    'Styled text (TuiStyle)',
    'Prompts API (how to run)',
  ];

  @override
  bool get quit => quitting;

  ShowcaseModel _copyWith({
    ShowcaseScreen? screen,
    int? menuCursor,
    TeaModel? child,
    bool? quitting,
    bool clearChild = false,
  }) {
    return ShowcaseModel(
      screen: screen ?? this.screen,
      menuCursor: menuCursor ?? this.menuCursor,
      child: clearChild ? null : (child ?? this.child),
      quitting: quitting ?? this.quitting,
    );
  }

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg) {
      return (_copyWith(), null);
    }

    if (screen == ShowcaseScreen.menu) {
      return _updateMenu(msg);
    }

    // Sub-screens: global back / exit handling
    if (msg is KeyMsg) {
      final k = msg.key;
      if (k == 'esc' || k == 'b' || k == 'q' || k == 'ctrl+c') {
        return (_copyWith(screen: ShowcaseScreen.menu, clearChild: true), null);
      }
    }

    final c = child;
    if (c == null) {
      // Static screens (style, prompts) have no child; do not treat as "invalid".
      if (screen == ShowcaseScreen.style || screen == ShowcaseScreen.prompts) {
        return (_copyWith(), null);
      }
      return (_copyWith(screen: ShowcaseScreen.menu), null);
    }

    final result = c.update(msg);
    final nextChild = result.$1;
    final cmd = result.$2;

    // ShoppingModel.quit would exit Program — lift to "return to menu" instead.
    if (screen == ShowcaseScreen.shopping && nextChild is ShoppingModel && nextChild.quit) {
      return (_copyWith(screen: ShowcaseScreen.menu, clearChild: true), null);
    }

    return (_copyWith(child: nextChild), cmd);
  }

  (TeaModel, Cmd?) _updateMenu(Msg msg) {
    if (msg is TickMsg) {
      return (_copyWith(), null);
    }
    if (msg is! KeyMsg) {
      return (_copyWith(), null);
    }
    switch (msg.key) {
      case 'ctrl+c':
      case 'q':
        return (_copyWith(quitting: true), null);
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
        return (_copyWith(screen: ShowcaseScreen.style), null);
      case 6:
        return (_copyWith(screen: ShowcaseScreen.prompts), null);
      default:
        return (_copyWith(), null);
    }
  }

  @override
  String view() {
    switch (screen) {
      case ShowcaseScreen.menu:
        return _menuView();
      case ShowcaseScreen.style:
        return _styleView();
      case ShowcaseScreen.prompts:
        return _promptsView();
      case ShowcaseScreen.shopping:
      case ShowcaseScreen.spinner:
      case ShowcaseScreen.progress:
      case ShowcaseScreen.textInput:
      case ShowcaseScreen.selectList:
        final body = child?.view() ?? '(no model)';
        return _wrapChild(body);
    }
  }

  String _menuView() {
    final b = StringBuffer()
      ..writeln(
        TuiStyle.wrap(
          'dart_tui — component showcase',
          open: '${TuiStyle.bold}${TuiStyle.fg256(141)}',
        ),
      )
      ..writeln('${TuiStyle.dim}Select a demo, Enter to open, q to exit.${TuiStyle.reset}')
      ..writeln();
    for (var i = 0; i < _menuItems.length; i++) {
      final mark = i == menuCursor ? '>' : ' ';
      b.writeln('$mark ${_menuItems[i]}');
    }
    b
      ..writeln()
      ..writeln(
        '${TuiStyle.dim}↑/↓ or j/k · Enter · q or ctrl+c quit${TuiStyle.reset}',
      );
    return b.toString();
  }

  String _styleView() {
    return _wrapChild('''
${TuiStyle.bold}TuiStyle${TuiStyle.reset} — ANSI helpers

  ${TuiStyle.wrap('256-color', open: TuiStyle.fg256(214))}
  ${TuiStyle.wrap('RGB red', open: TuiStyle.fgRgb(255, 80, 80))}
  ${TuiStyle.wrap('dim secondary', open: TuiStyle.dim)}
  ${TuiStyle.wrap('bold label', open: TuiStyle.bold)}

Use these to build richer views in your own [TeaModel.view].
''');
  }

  String _promptsView() {
    return _wrapChild('''
${TuiStyle.bold}Prompts API${TuiStyle.reset}

  • promptSelect(choices)  → Future<String?>
  • promptConfirm(text)    → Future<bool?>
  • promptInput(label)     → Future<String?>

Each runs its own [Program] on stdin. For a small script that chains them,
see: ${TuiStyle.wrap('example/prompts_chain.dart', open: TuiStyle.fg256(109))}

(They are not nested inside this showcase to avoid two programs fighting for the terminal.)
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

enum ShowcaseScreen {
  menu,
  shopping,
  spinner,
  progress,
  textInput,
  selectList,
  style,
  prompts,
}

/// Drives [ProgressModel] with a sawtooth 0→1 using [TickMsg].
final class ProgressDemoModel extends TeaModel {
  ProgressDemoModel({this.t = 0});

  final double t;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      var next = t + 0.02;
      if (next > 1.0) {
        next = 0;
      }
      return (ProgressDemoModel(t: next), null);
    }
    return (this, null);
  }

  @override
  String view() {
    return ProgressModel(
      fraction: t,
      width: 48,
      label: TuiStyle.wrap('download', open: TuiStyle.fg256(109)),
    ).view();
  }
}
