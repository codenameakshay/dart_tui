import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('paginator moves across pages with keys', () {
    final m = PaginatorModel(page: 0, totalPages: 3);
    final moved = m
        .update(
          KeyPressMsg(const TeaKey(code: KeyCode.right)),
        )
        .$1 as PaginatorModel;
    expect(moved.page, 1);

    final back = moved
        .update(
          KeyPressMsg(const TeaKey(code: KeyCode.left)),
        )
        .$1 as PaginatorModel;
    expect(back.page, 0);
  });

  test('help view prints entries', () {
    final model = HelpModel(
      entries: const [
        (key: 'q', description: 'quit'),
        (key: 'enter', description: 'select'),
      ],
    );
    final view = model.view().content;
    expect(view, contains('q'));
    expect(view, contains('quit'));
    expect(view, contains('enter'));
    expect(view, contains('select'));
  });
}
