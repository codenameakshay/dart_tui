part of 'program.dart';

/// Line-based prompt I/O for plain mode (see [withPlainMode]). Internal: the
/// barrels hide it.
///
/// Answers are read through the same stdin owner as [Program], so a plain
/// prompt and a full program can follow each other in one process. Bytes
/// read past the last answer go back to that owner for the next reader.
final class PlainSession {
  PlainSession._(this._program)
      : _out = _program._output,
        _shared = _program._usesSharedStdin,
        _source = _program._disableInput ? null : _program._input;

  /// A session for [program] when it is in plain mode, else null.
  static PlainSession? open(Program program) {
    return _isPlain(program) ? PlainSession._(program) : null;
  }

  static bool _isPlain(Program p) {
    final forced = p._plain;
    if (forced != null) return forced;
    final env = p._environment;
    if (_flag(env['DART_TUI_ACCESSIBLE']) || _flag(env['ACCESSIBLE'])) {
      return true;
    }
    // Tests that pass their own input or output keep the TUI.
    if (!p._usesSharedStdin || !identical(p._output, stdout)) return false;
    return !stdin.hasTerminal || isPlainOutput(env, stdoutIsTerminal());
  }

  static bool _flag(String? value) =>
      value != null &&
      value.isNotEmpty &&
      value != '0' &&
      value.toLowerCase() != 'false';

  final Program _program;
  final IOSink _out;
  final bool _shared;
  final Stream<List<int>>? _source;
  StreamSubscription<List<int>>? _sub;
  final List<int> _bytes = [];
  bool _ended = false;
  Completer<void>? _wake;

  /// A terminal echoes what the user types; anything else does not.
  bool get _echoedByTerminal => _shared && stdin.hasTerminal;

  void write(String text) =>
      _out.write(stripAnsiSequences(text).replaceAll('\x1b', ''));
  void writeln([String text = '']) => write('$text\n');

  /// Runs [body], then gives unread input back to the stdin owner.
  Future<T> run<T>(Future<T> Function(PlainSession session) body) async {
    try {
      return await body(this);
    } finally {
      await close();
    }
  }

  Future<void> close() async {
    final sub = _sub;
    _sub = null;
    if (sub == null) return;
    if (_shared) _sharedStdin.unread(_bytes);
    _bytes.clear();
    await sub.cancel();
  }

  /// Reads one answer, or null at the end of input. Escape sequences and
  /// control characters are dropped. Input that is not echoed by a terminal
  /// is echoed here, so the output reads like a transcript.
  Future<String?> readLine({bool secret = false}) async {
    final echoedByTerminal = _echoedByTerminal;
    final hideEcho = secret && echoedByTerminal;
    final previousEcho = hideEcho ? stdin.echoMode : null;
    if (hideEcho) _setEcho(false);
    try {
      while (true) {
        final newline = _bytes.indexOf(0x0a);
        if (newline >= 0 || _ended) {
          if (newline < 0 && _bytes.isEmpty) {
            _out.writeln();
            return null;
          }
          final end = newline < 0 ? _bytes.length : newline;
          final line = stripAnsiSequences(
            utf8.decode(_bytes.sublist(0, end), allowMalformed: true),
          ).replaceAll(_controlChars, '');
          _bytes.removeRange(0, newline < 0 ? end : end + 1);
          if (!echoedByTerminal) {
            _out.writeln(secret ? '' : line);
          } else if (hideEcho) {
            _out.writeln();
          }
          return line;
        }
        _listen();
        if (_ended) continue;
        await (_wake = Completer<void>()).future;
      }
    } finally {
      if (previousEcho != null) _setEcho(previousEcho);
    }
  }

  static final _controlChars = RegExp(r'[\x00-\x1f\x7f]');

  void _listen() {
    if (_sub != null || _ended) return;
    if (_shared) _program._checkStdinIsolate();
    final source = _shared ? _sharedStdin.claim() : _source;
    if (source == null) {
      _ended = true;
      return;
    }
    _sub = source.listen(
      (bytes) {
        _bytes.addAll(bytes);
        _wakeUp();
      },
      onError: (Object _) {
        _ended = true;
        _wakeUp();
      },
      onDone: () {
        _ended = true;
        _wakeUp();
      },
      cancelOnError: true,
    );
  }

  void _wakeUp() {
    final wake = _wake;
    _wake = null;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  static void _setEcho(bool on) {
    try {
      stdin.echoMode = on;
    } on StdinException {
      // Not a terminal.
    }
  }

  /// Writes [heading] and the numbered [labels], then asks for a number.
  /// Empty input takes [defaultIndex] when there is one. With [matchText],
  /// text that matches exactly one label (case-insensitively, exactly or as
  /// a substring) is accepted too. Returns the index, or null at the end of
  /// input.
  Future<int?> askChoice(
    List<String> heading,
    List<String> labels, {
    int? defaultIndex,
    bool matchText = false,
  }) =>
      _ask(_choiceQuestion(heading, labels,
          defaultIndex: defaultIndex, matchText: matchText));

  /// Like [askChoice], for several answers given as comma-separated numbers.
  /// Empty input keeps [defaults].
  Future<Set<int>?> askMany(
    List<String> heading,
    List<String> labels, {
    Set<int> defaults = const {},
    int? limit,
  }) =>
      _ask(_manyQuestion(heading, labels, defaults: defaults, limit: limit));

  /// Asks [question] with `(Y/n)` or `(y/N)`; empty input takes
  /// [defaultValue]. `y`, `yes`, `n`, `no` and the [yes] / [no] labels are
  /// accepted in any case. Returns null at the end of input.
  Future<bool?> askConfirm(
    String question,
    bool defaultValue, {
    String yes = 'Yes',
    String no = 'No',
  }) =>
      _ask(_confirmQuestion(question, defaultValue, yes: yes, no: no));

  /// Writes [prompt] and reads one line; empty input takes [initial].
  Future<String?> askText(
    String prompt, {
    String initial = '',
    bool secret = false,
  }) =>
      _ask(_textQuestion(prompt, initial: initial, secret: secret));

  Future<T?> _ask<T extends Object>(_Question<T> question) async {
    question.intro.forEach(writeln);
    while (true) {
      write(question.prompt);
      final line = await readLine(secret: question.secret);
      if (line == null) return null;
      switch (question.parse(line)) {
        case _Retry(:final message):
          writeln(message);
        case final T answer:
          return answer;
      }
    }
  }
}

/// A plain-mode question, shared by [PlainSession] and the sync prompts'
/// plain session: [intro] is written once, then [prompt] before each line
/// until [parse] accepts one.
final class _Question<T extends Object> {
  const _Question(this.intro, this.prompt, this.parse, {this.secret = false});

  final List<String> intro;
  final String prompt;
  final bool secret;

  /// The answer, or a [_Retry] with the message to write before asking again.
  final Object Function(String line) parse;
}

final class _Retry {
  const _Retry(this.message);
  final String message;
}

List<String> _intro(List<String> heading, List<String> labels) => [
      for (final line in heading)
        if (line.isNotEmpty) line,
      for (var i = 0; i < labels.length; i++) '${i + 1}. ${labels[i]}',
    ];

_Question<int> _choiceQuestion(
  List<String> heading,
  List<String> labels, {
  int? defaultIndex,
  bool matchText = false,
}) {
  final hint = defaultIndex == null ? '' : ' [${defaultIndex + 1}]';
  return _Question(_intro(heading, labels), 'Enter a number$hint: ', (line) {
    final answer = line.trim();
    if (answer.isEmpty && defaultIndex != null) return defaultIndex;
    final n = int.tryParse(answer);
    if (n != null && n >= 1 && n <= labels.length) return n - 1;
    if (matchText && answer.isNotEmpty) {
      final query = answer.toLowerCase();
      final lower = [for (final l in labels) l.toLowerCase()];
      final exact = lower.indexOf(query);
      if (exact >= 0) return exact;
      final hits = [
        for (var i = 0; i < lower.length; i++)
          if (lower[i].contains(query)) i,
      ];
      if (hits.length == 1) return hits.single;
    }
    return _Retry(matchText
        ? 'Enter a number from 1 to ${labels.length}, or text that '
            'matches one option.'
        : 'Enter a number from 1 to ${labels.length}.');
  });
}

_Question<Set<int>> _manyQuestion(
  List<String> heading,
  List<String> labels, {
  Set<int> defaults = const {},
  int? limit,
}) {
  final most = limit == null ? '' : ' (up to $limit)';
  final hint = defaults.isEmpty
      ? ''
      : ' [${(defaults.toList()..sort()).map((i) => i + 1).join(',')}]';
  return _Question(
    _intro(heading, labels),
    'Enter numbers separated by commas$most$hint: ',
    (line) {
      final parts = [
        for (final part in line.split(','))
          if (part.trim().isNotEmpty) part.trim(),
      ];
      if (parts.isEmpty) return defaults;
      final picks = <int>{};
      for (final part in parts) {
        final n = int.tryParse(part);
        if (n == null || n < 1 || n > labels.length) {
          return _Retry('Enter numbers from 1 to ${labels.length}, like 1,3.');
        }
        picks.add(n - 1);
      }
      if (limit != null && picks.length > limit) {
        return _Retry('Choose at most $limit.');
      }
      return picks;
    },
  );
}

_Question<bool> _confirmQuestion(
  String question,
  bool defaultValue, {
  String yes = 'Yes',
  String no = 'No',
}) {
  final hint = defaultValue ? '(Y/n)' : '(y/N)';
  final prompt = question.isEmpty ? '$hint ' : '$question $hint ';
  return _Question(const [], prompt, (line) {
    final answer = line.trim().toLowerCase();
    if (answer.isEmpty) return defaultValue;
    if (answer == 'y' || answer == 'yes' || answer == yes.toLowerCase()) {
      return true;
    }
    if (answer == 'n' || answer == 'no' || answer == no.toLowerCase()) {
      return false;
    }
    return const _Retry('Enter y or n.');
  });
}

_Question<String> _textQuestion(
  String prompt, {
  String initial = '',
  bool secret = false,
}) =>
    _Question(const [], prompt, (line) => line.isEmpty ? initial : line,
        secret: secret);
