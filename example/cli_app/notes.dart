// A small "notes" CLI built on CliRunner: commands in two categories, a
// prompt, a progress line, global flags and exit codes.
//
//   dart run example/cli_app/notes.dart --help
//   dart run example/cli_app/notes.dart add "Buy milk" --priority high
//   dart run example/cli_app/notes.dart list --all
//   dart run example/cli_app/notes.dart done 1
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/cli.dart';

Future<void> main(List<String> args) => NotesRunner().runAndExit(args);

class NotesRunner extends CliRunner<int> {
  NotesRunner({super.logger, super.usageLineLength})
      : super('notes', 'Keep a short list of notes in a JSON file.',
            version: '1.0.0') {
    argParser.addOption(
      'file',
      abbr: 'f',
      valueHelp: 'path',
      help: 'Where the notes are kept.',
      defaultsTo: '~/.notes.json',
    );
    addCommand(AddCommand());
    addCommand(DoneCommand());
    addCommand(ListCommand());
  }

  @override
  String get usageFooter => 'Notes are plain JSON; edit them with any tool.';
}

/// Shared by the commands: the notes file as a list of maps.
abstract class NotesCommand extends CliCommand<int> {
  File get _file {
    final path = globalResults!.option('file')!;
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    return File(path.startsWith('~/') && home != null
        ? '$home${path.substring(1)}'
        : path);
  }

  List<Map<String, Object?>> load() => _file.existsSync()
      ? [
          for (final note in jsonDecode(_file.readAsStringSync()) as List)
            (note as Map).cast<String, Object?>(),
        ]
      : [];

  void save(List<Map<String, Object?>> notes) =>
      _file.writeAsStringSync(jsonEncode(notes));
}

class AddCommand extends NotesCommand {
  AddCommand() {
    argParser.addOption(
      'priority',
      abbr: 'p',
      help: 'How urgent the note is.',
      allowed: ['low', 'normal', 'high'],
      defaultsTo: 'normal',
    );
  }

  @override
  String get name => 'add';
  @override
  String get description => 'Add a note. Asks for the text when it is not '
      'given.';
  @override
  String get category => 'Write';
  @override
  String get invocation => 'notes add [text] [arguments]';
  @override
  List<String> get examples => [
        'notes add "Buy milk" --priority high',
        'notes add',
      ];

  @override
  Future<int> run() async {
    var text = argResults!.rest.join(' ');
    var priority = argResults!.option('priority')!;
    if (text.isEmpty) {
      text = await logger.prompt('What should the note say?');
      if (text.isEmpty) usageException('A note needs some text.');
      if (!argResults!.wasParsed('priority')) {
        priority = await logger.chooseOne('Priority?',
            choices: ['low', 'normal', 'high'], defaultValue: priority);
      }
    }
    final progress = logger.progress('Saving');
    final notes = load()
      ..add({'text': text, 'priority': priority, 'done': false});
    save(notes);
    // A pause so the progress line is visible in the demo.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    progress.complete('Saved note ${notes.length}');
    logger.detail('Wrote ${_file.path}');
    return 0;
  }
}

class DoneCommand extends NotesCommand {
  @override
  String get name => 'done';
  @override
  String get description => 'Mark a note as done.';
  @override
  String get category => 'Write';
  @override
  String get invocation => 'notes done <number>';
  @override
  List<String> get examples => ['notes done 2'];

  @override
  int run() {
    final rest = argResults!.rest;
    final index = rest.length == 1 ? int.tryParse(rest.single) : null;
    final notes = load();
    if (index == null || index < 1 || index > notes.length) {
      usageException('Give the number of a note, from 1 to ${notes.length}.');
    }
    notes[index - 1]['done'] = true;
    save(notes);
    logger.success('Done: ${notes[index - 1]['text']}');
    return 0;
  }
}

class ListCommand extends NotesCommand {
  ListCommand() {
    argParser.addFlag('all', abbr: 'a', help: 'Include notes that are done.');
  }

  @override
  String get name => 'list';
  @override
  String get description => 'List the notes.';
  @override
  String get category => 'Read';
  @override
  List<String> get aliases => ['ls'];
  @override
  bool get takesArguments => false;

  @override
  int run() {
    final notes = load();
    final all = argResults!.flag('all');
    var shown = 0;
    for (final (i, note) in notes.indexed) {
      final done = note['done'] == true;
      if (done && !all) continue;
      shown++;
      final line = '${i + 1}. [${done ? 'x' : ' '}] ${note['text']} '
          '(${note['priority']})';
      logger.info(line);
    }
    if (shown == 0) logger.info('No notes. Add one with "notes add".');
    return 0;
  }
}
