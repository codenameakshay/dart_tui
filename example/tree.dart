import 'package:dart_tui/dart_tui.dart';

void main() async {
  await Program().run(_TreeShowcaseModel());
}

const _sampleRoot = TreeNode(
  label: 'Languages',
  isExpanded: true,
  children: [
    TreeNode(
      label: 'Dart',
      isExpanded: true,
      children: [
        TreeNode(
          label: 'Frameworks',
          isExpanded: true,
          children: [
            TreeNode(label: 'Flutter'),
            TreeNode(label: 'dart_tui'),
            TreeNode(label: 'Shelf'),
          ],
        ),
        TreeNode(
          label: 'Tools',
          isExpanded: false,
          children: [
            TreeNode(label: 'pub.dev'),
            TreeNode(label: 'dart analyze'),
            TreeNode(label: 'dart compile'),
          ],
        ),
      ],
    ),
    TreeNode(
      label: 'Go',
      isExpanded: true,
      children: [
        TreeNode(
          label: 'Charmbracelet',
          isExpanded: true,
          children: [
            TreeNode(label: 'Bubble Tea'),
            TreeNode(label: 'Lip Gloss'),
            TreeNode(label: 'Bubbles'),
          ],
        ),
        TreeNode(label: 'Cobra'),
        TreeNode(label: 'Gin'),
      ],
    ),
    TreeNode(
      label: 'Rust',
      isExpanded: false,
      children: [
        TreeNode(label: 'Tokio'),
        TreeNode(label: 'Axum'),
        TreeNode(label: 'ratatui'),
      ],
    ),
    TreeNode(label: 'Python'),
  ],
);

final class _TreeShowcaseModel extends TeaModel {
  _TreeShowcaseModel({TreeModel? tree})
      : tree = tree ??
            TreeModel(
              root: _sampleRoot,
              height: 20,
            );

  final TreeModel tree;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, quit);
      }
    }
    final (nextTree, _) = tree.update(msg);
    return (_TreeShowcaseModel(tree: nextTree as TreeModel), null);
  }

  @override
  View view() {
    final header = const Style(
          foregroundRgb: RgbColor(203, 166, 247), // Mauve
          isBold: true,
        ).render('  Tree Component') +
        const Style(
          foregroundRgb: RgbColor(88, 91, 112),
          isDim: true,
        ).render('  ↑↓/jk navigate · Enter/Space toggle · →l expand · ←h collapse · q quit');

    return newView('$header\n\n${tree.view().content}\n');
  }
}
