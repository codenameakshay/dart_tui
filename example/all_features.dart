// One-file, detailed tour of current dart_tui APIs.
// Run:
//   fvm dart run example/all_features.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(
      altScreen: true,
      tickInterval: Duration(milliseconds: 100),
    ),
  ).run(AllFeaturesModel());
}

final class AllFeaturesModel extends TeaModel {
  AllFeaturesModel({
    this.page = 0,
    this.progress = 0,
    this.text = '',
    this.logs = const <String>[],
  });

  final int page;
  final double progress;
  final String text;
  final List<String> logs;

  static const _pages = <String>[
    'Overview',
    'Style',
    'Components',
    'Commands',
    'Messages',
  ];

  AllFeaturesModel _copyWith({
    int? page,
    double? progress,
    String? text,
    List<String>? logs,
  }) {
    return AllFeaturesModel(
      page: page ?? this.page,
      progress: progress ?? this.progress,
      text: text ?? this.text,
      logs: logs ?? this.logs,
    );
  }

  List<String> _push(String line) {
    final next = [...logs, line];
    return next.length > 10 ? next.sublist(next.length - 10) : next;
  }

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      final p = progress + 0.02 > 1 ? 0.0 : progress + 0.02;
      return (_copyWith(progress: p), null);
    }

    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
        case 'left':
        case 'h':
          return (_copyWith(page: page > 0 ? page - 1 : 0), null);
        case 'right':
        case 'l':
          return (
            _copyWith(page: page < _pages.length - 1 ? page + 1 : page),
            null
          );
        case 'backspace':
          if (text.isNotEmpty) {
            return (_copyWith(text: text.substring(0, text.length - 1)), null);
          }
          return (this, null);
        case 'p':
          return (
            _copyWith(logs: _push('Println command sent')),
            println('all_features: println'),
          );
        case 'w':
          return (
            _copyWith(logs: _push('RequestWindowSize command sent')),
            () => requestWindowSize()
          );
        case 'f':
          return (
            _copyWith(logs: _push('RequestForegroundColor command sent')),
            () => requestForegroundColor()
          );
        default:
          if (msg.key.length == 1) {
            return (_copyWith(text: text + msg.key), null);
          }
      }
    }

    if (msg is WindowSizeMsg) {
      return (
        _copyWith(logs: _push('WindowSizeMsg ${msg.width}x${msg.height}')),
        null
      );
    }
    if (msg is ForegroundColorMsg) {
      return (
        _copyWith(
            logs: _push('ForegroundColorMsg 0x${msg.rgb.toRadixString(16)}')),
        null
      );
    }
    if (msg is PasteStartMsg) {
      return (_copyWith(logs: _push('PasteStartMsg')), null);
    }
    if (msg is PasteMsg) {
      return (_copyWith(logs: _push('PasteMsg "${msg.content}"')), null);
    }
    if (msg is PasteEndMsg) {
      return (_copyWith(logs: _push('PasteEndMsg')), null);
    }
    if (msg is FocusMsg) {
      return (_copyWith(logs: _push('FocusMsg')), null);
    }
    if (msg is BlurMsg) {
      return (_copyWith(logs: _push('BlurMsg')), null);
    }

    return (this, null);
  }

  @override
  View view() {
    final pageTitle = _pages[page];
    final header = const Style(
      foreground256: 141,
      isBold: true,
      padding: EdgeInsets.all(1),
      border: Border.rounded,
    ).render('dart_tui all_features • $pageTitle');

    final body = switch (page) {
      0 => _overview(),
      1 => _style(),
      2 => _components(),
      3 => _commands(),
      4 => _messages(),
      _ => 'Unknown page',
    };

    return newView('''
$header

$body

${TuiStyle.dim}Left/Right switch pages • q quit • p/w/f run command demos${TuiStyle.reset}
''');
  }

  String _overview() => '''
This example demonstrates:
  • Model/update/view loop
  • Tick-driven animation
  • Style + TuiStyle helpers
  • Bubbles components
  • Cmd helpers + typed Msg handling
''';

  String _style() {
    final box = const Style()
        .foregroundColor256(39)
        .withPadding(const EdgeInsets.all(1))
        .withBorder(Border.rounded)
        .render('Style + border + padding');
    return '''
$box

Legacy helper: ${TuiStyle.wrap('TuiStyle.fg256(208)', open: TuiStyle.fg256(208))}
''';
  }

  String _components() {
    final paginator =
        PaginatorModel(page: (progress * 7).round(), totalPages: 8)
            .view()
            .content;
    final help = HelpModel(
      entries: const [
        (key: 'q', description: 'quit'),
        (key: 'left/right', description: 'switch pages'),
      ],
    ).view().content;
    final progressView =
        ProgressModel(fraction: progress, width: 30, label: 'progress')
            .view()
            .content;
    return '''
$progressView

$paginator

$help
''';
  }

  String _commands() => '''
Press:
  • p => println
  • w => requestWindowSize
  • f => requestForegroundColor

Recent command/event log:
${logs.isEmpty ? '  (none yet)' : logs.map((e) => '  - $e').join('\n')}
''';

  String _messages() => '''
Type to append text, backspace to delete:
  "$text"

Events being tracked:
  • KeyMsg
  • WindowSizeMsg
  • ForegroundColorMsg
  • Focus/Blur
  • PasteStart/Paste/PasteEnd
''';
}
