// Ported from charmbracelet/bubbletea examples/isbn-form
import 'package:dart_tui/dart_tui.dart';

bool _isValidIsbn13(String s) {
  final digits = s.replaceAll(RegExp(r'[\s\-]'), '');
  if (digits.length != 13) return false;
  if (!RegExp(r'^\d+$').hasMatch(digits)) return false;
  // GS1 prefix check (978 or 979)
  if (!digits.startsWith('978') && !digits.startsWith('979')) return false;
  // Checksum
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(digits[i]) * (i.isEven ? 1 : 3);
  }
  final check = (10 - (sum % 10)) % 10;
  return check == int.parse(digits[12]);
}

Future<void> main() async {
  await Program().run(IsbnFormModel());
}

final class IsbnFormModel extends TeaModel {
  IsbnFormModel({
    TextInputModel? input,
    this.errorMsg = '',
    this.result = '',
    this.searched = false,
  }) : input = input ??
            TextInputModel(
              placeholder: '978-0-06-112008-4',
              label: 'ISBN-13: ',
              charLimit: 20,
              validate: _isValidIsbn13,
            );

  final TextInputModel input;
  final String errorMsg;
  final String result;
  final bool searched;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is ValidationFailedMsg) {
      return (
        IsbnFormModel(
          input: input,
          errorMsg: 'Invalid ISBN-13 checksum',
        ),
        null,
      );
    }
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'ctrl+c':
        case 'esc':
          return (this, () => quit());
        case 'enter':
          if (_isValidIsbn13(input.value)) {
            return (
              IsbnFormModel(
                input: input,
                result: 'Searching for ISBN: ${input.value}...',
                searched: true,
              ),
              null,
            );
          }
      }
    }
    final (next, cmd) = input.update(msg);
    return (
      IsbnFormModel(
        input: next as TextInputModel,
        errorMsg: errorMsg,
        result: result,
        searched: searched,
      ),
      cmd,
    );
  }

  @override
  View view() {
    final isValid = _isValidIsbn13(input.value);
    final header = const Style().bold().render('Book Search');
    final b = StringBuffer('$header\n\n');
    b.writeln(input.view().content);
    if (errorMsg.isNotEmpty) {
      b.writeln(const Style().foregroundColor256(196).render('  ⚠ $errorMsg'));
    } else if (isValid) {
      b.writeln(
        const Style().foregroundColor256(82).render('  ✓ Valid ISBN-13'),
      );
    }
    b.writeln();
    if (searched) {
      b.writeln(const Style().foregroundColor256(82).render(result));
    } else {
      final btnStyle = isValid
          ? const Style().bold().foregroundColor256(82)
          : const Style().dim();
      b.writeln(
        btnStyle.render('[ Search ]') +
            (isValid ? '' : '  (enter a valid ISBN first)'),
      );
    }
    b.write('\nenter: search  •  esc: quit');
    return newView(b.toString());
  }
}
