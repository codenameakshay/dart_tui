import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

/// Helper: create a [KeyPressMsg] for a single character key.
KeyPressMsg _char(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));

/// Helper: create a [KeyPressMsg] for a special key.
KeyPressMsg _special(KeyCode code) => KeyPressMsg(TeaKey(code: code));

void main() {
  group('TreeNode', () {
    test('isLeaf when no children', () {
      const node = TreeNode(label: 'leaf');
      expect(node.isLeaf, isTrue);
    });

    test('not isLeaf when children present', () {
      const node = TreeNode(
        label: 'parent',
        children: [TreeNode(label: 'child')],
      );
      expect(node.isLeaf, isFalse);
    });

    test('copyWith updates fields', () {
      const node = TreeNode(label: 'a', isExpanded: true);
      final updated = node.copyWith(isExpanded: false);
      expect(updated.isExpanded, isFalse);
      expect(updated.label, 'a');
    });
  });

  group('TreeModel', () {
    late TreeNode sampleRoot;

    setUp(() {
      sampleRoot = const TreeNode(
        label: 'root',
        isExpanded: true,
        children: [
          TreeNode(
            label: 'parent A',
            isExpanded: true,
            children: [
              TreeNode(label: 'leaf 1'),
              TreeNode(label: 'leaf 2'),
            ],
          ),
          TreeNode(label: 'leaf 3'),
        ],
      );
    });

    test('nodeCount includes root and all expanded nodes', () {
      final model = TreeModel(root: sampleRoot, height: 20);
      // root + parent A + leaf 1 + leaf 2 + leaf 3 = 5
      expect(model.nodeCount, 5);
    });

    test('nodeCount excludes children of collapsed nodes', () {
      const collapsed = TreeNode(
        label: 'root',
        isExpanded: true,
        children: [
          TreeNode(
            label: 'parent A',
            isExpanded: false,
            children: [TreeNode(label: 'leaf 1')],
          ),
        ],
      );
      final model = TreeModel(root: collapsed, height: 20);
      // root + parent A (collapsed) = 2 (leaf 1 hidden)
      expect(model.nodeCount, 2);
    });

    test('cursor moves down with j', () {
      final model = TreeModel(root: sampleRoot, height: 20);
      final (next, _) = model.update(_char('j'));
      expect((next as TreeModel).cursor, 1);
    });

    test('cursor moves down with down arrow', () {
      final model = TreeModel(root: sampleRoot, height: 20);
      final (next, _) = model.update(_special(KeyCode.down));
      expect((next as TreeModel).cursor, 1);
    });

    test('cursor moves up with k', () {
      final model = TreeModel(root: sampleRoot, cursor: 2, height: 20);
      final (next, _) = model.update(_char('k'));
      expect((next as TreeModel).cursor, 1);
    });

    test('cursor clamps at 0', () {
      final model = TreeModel(root: sampleRoot, cursor: 0, height: 20);
      final (next, _) = model.update(_char('k'));
      expect((next as TreeModel).cursor, 0);
    });

    test('cursor clamps at last node', () {
      final model = TreeModel(root: sampleRoot, cursor: 4, height: 20);
      final (next, _) = model.update(_char('j'));
      expect((next as TreeModel).cursor, 4);
    });

    test('enter on non-leaf collapses node and hides children', () {
      // cursor=1 is parent A (expanded, 2 children visible)
      final model = TreeModel(root: sampleRoot, cursor: 1, height: 20);
      final (next, _) = model.update(_special(KeyCode.enter));
      final nextModel = next as TreeModel;
      // parent A collapsed: root + parent A + leaf 3 = 3
      expect(nextModel.nodeCount, 3);
    });

    test('enter on collapsed node expands it', () {
      // First collapse parent A
      final model = TreeModel(root: sampleRoot, cursor: 1, height: 20);
      final (collapsed, _) = model.update(_special(KeyCode.enter));
      expect((collapsed as TreeModel).nodeCount, 3);
      // Then expand it again
      final (expanded, _) = collapsed.update(_special(KeyCode.enter));
      expect((expanded as TreeModel).nodeCount, 5);
    });

    test('enter on leaf does nothing', () {
      // cursor=2 is leaf 1 (no children)
      final model = TreeModel(root: sampleRoot, cursor: 2, height: 20);
      final (next, _) = model.update(_special(KeyCode.enter));
      expect(identical(next, model), isTrue);
    });

    test('right (l) expands a collapsed node', () {
      const collapsed = TreeNode(
        label: 'root',
        isExpanded: true,
        children: [
          TreeNode(
            label: 'parent A',
            isExpanded: false,
            children: [TreeNode(label: 'child')],
          ),
        ],
      );
      final model = TreeModel(root: collapsed, cursor: 1, height: 20);
      final (next, _) = model.update(_char('l'));
      expect((next as TreeModel).nodeCount, 3);
    });

    test('left (h) collapses an expanded node', () {
      // cursor=1 is parent A (expanded)
      final model = TreeModel(root: sampleRoot, cursor: 1, height: 20);
      final (next, _) = model.update(_char('h'));
      expect((next as TreeModel).nodeCount, 3);
    });

    test('view contains root label', () {
      final model = TreeModel(root: sampleRoot, height: 20);
      expect(model.view().content, contains('root'));
    });

    test('view contains connector characters for children', () {
      final model = TreeModel(root: sampleRoot, height: 20);
      final content = model.view().content;
      expect(content, contains('├─'));
      expect(content, contains('└─'));
    });

    test('view contains all expanded node labels', () {
      final model = TreeModel(root: sampleRoot, height: 20);
      final content = model.view().content;
      expect(content, contains('parent A'));
      expect(content, contains('leaf 1'));
      expect(content, contains('leaf 2'));
      expect(content, contains('leaf 3'));
    });

    test('view hides labels of collapsed nodes\' children', () {
      // Collapse parent A, then check leaf 1 is not in view
      final model = TreeModel(root: sampleRoot, cursor: 1, height: 20);
      final (collapsed, _) = model.update(_special(KeyCode.enter));
      final content = (collapsed as TreeModel).view().content;
      expect(content, isNot(contains('leaf 1')));
      expect(content, isNot(contains('leaf 2')));
    });

    test('scroll window limits rendered rows', () {
      final model = TreeModel(root: sampleRoot, height: 2);
      // Only 2 rows visible
      final lines = model.view().content.split('\n');
      expect(lines.length, 2);
    });

    test('expand icon shown for expanded non-leaf', () {
      final model = TreeModel(
        root: sampleRoot,
        height: 20,
        styles: const TreeStyles(
          connector: Style(),
          label: Style(),
          selectedLabel: Style(),
          expandedIcon: Style(),
          collapsedIcon: Style(),
        ),
      );
      expect(model.view().content, contains('▾'));
    });

    test('collapse icon shown for collapsed non-leaf', () {
      final model = TreeModel(
        root: sampleRoot,
        cursor: 1,
        height: 20,
        styles: const TreeStyles(
          connector: Style(),
          label: Style(),
          selectedLabel: Style(),
          expandedIcon: Style(),
          collapsedIcon: Style(),
        ),
      );
      final (collapsed, _) = model.update(_special(KeyCode.enter));
      expect((collapsed as TreeModel).view().content, contains('▸'));
    });
  });
}
