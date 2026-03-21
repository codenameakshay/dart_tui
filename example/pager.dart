// Scrollable pager using ViewportModel.
// Run: fvm dart run example/pager.dart

import 'package:dart_tui/dart_tui.dart';

const _longText = '''
Chapter 1: The Beginning

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

Chapter 2: The Journey

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.

Chapter 3: The Challenge

Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium
doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore
veritatis et quasi architecto beatae vitae dicta sunt explicabo.

Chapter 4: The Resolution

Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed
quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.
Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet.

Chapter 5: The Conclusion

At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis
praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias
excepturi sint occaecati cupiditate non provident.

Chapter 6: Epilogue

Similique sunt in culpa qui officia deserunt mollitia animi, id est laborum et
dolorum fuga. Et harum quidem rerum facilis est et expedita distinctio.

Nam libero tempore, cum soluta nobis est eligendi optio cumque nihil impedit
quo minus id quod maxime placeat facere possimus.

Chapter 7: Appendix

Temporibus autem quibusdam et aut officiis debitis aut rerum necessitatibus
saepe eveniet ut et voluptates repudiandae sint et molestiae non recusandae.
Itaque earum rerum hic tenetur a sapiente delectus.

Chapter 8: Index

Ut aut reiciendis voluptatibus maiores alias consequatur aut perferendis
doloribus asperiores repellat. This is the final line of the long document.
''';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(PagerModel());
}

final class PagerModel extends TeaModel {
  PagerModel({ViewportModel? viewport})
      : viewport = viewport ??
            ViewportModel(content: _longText, width: 80, height: 20);

  final ViewportModel viewport;

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
      final (next, cmd) = viewport.update(msg);
      return (PagerModel(viewport: next as ViewportModel), cmd);
    }
    return (this, null);
  }

  @override
  View view() {
    final pct = (viewport.scrollPercent * 100).round();
    final atEnd = viewport.atBottom ? ' (END)' : '';
    return newView('''
Pager demo — Up/Down/PgUp/PgDn/g/G to scroll · q to quit

${viewport.view().content}

── $pct%$atEnd ──────────────────────────────────────────────''');
  }
}
