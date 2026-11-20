import 'package:__name__/__name__.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

void main() {
  test('shows the list and the help bar', () async {
    final t = TuiTester(AppModel());
    addTearDown(t.dispose);
    expect(t.screen, contains('› [ ] Run the app'));
    expect(t.screen, contains('q quit'));
  });

  test('enter checks the item under the cursor', () async {
    final t = TuiTester(AppModel());
    addTearDown(t.dispose);
    await t.press('down');
    await t.press('enter');
    expect(t.screen, contains('› [x] Read lib/__name__.dart'));
    await t.press('enter');
    expect(t.screen, contains('› [ ] Read lib/__name__.dart'));
  });

  test('checking an empty list does not add a nonexistent item', () async {
    final t = TuiTester(AppModel(items: const []));
    addTearDown(t.dispose);
    expect(t.screen, contains('q quit'));
    await t.press('down');
    expect((t.model as AppModel).cursor, 0);
    await t.press('enter');
    expect((t.model as AppModel).checked, isEmpty);
    await t.press('space');
    expect((t.model as AppModel).checked, isEmpty);
    await t.press('q');
    expect((await t.done()).model, isA<AppModel>());
  });

  test('q quits', () async {
    final t = TuiTester(AppModel());
    addTearDown(t.dispose);
    await t.press('space');
    await t.press('q');
    final result = await t.done();
    expect((result.model! as AppModel).checked, {0});
  });
}
