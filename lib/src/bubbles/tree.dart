import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

// ── TreeNode data structure ───────────────────────────────────────────────────

/// A node in a [TreeModel].
///
/// [TreeNode] is immutable. Use [copyWith] to produce modified versions.
final class TreeNode {
  const TreeNode({
    required this.label,
    this.children = const [],
    this.isExpanded = true,
  });

  final String label;
  final List<TreeNode> children;

  /// Whether the node is currently showing its children.
  final bool isExpanded;

  bool get isLeaf => children.isEmpty;

  TreeNode copyWith({
    String? label,
    List<TreeNode>? children,
    bool? isExpanded,
  }) =>
      TreeNode(
        label: label ?? this.label,
        children: children ?? this.children,
        isExpanded: isExpanded ?? this.isExpanded,
      );
}

// ── TreeStyles ─────────────────────────────────────────────────────────────────

/// Style configuration for [TreeModel].
final class TreeStyles {
  const TreeStyles({
    this.connector = const Style(),
    this.label = const Style(),
    this.selectedLabel = const Style(),
    this.expandedIcon = const Style(),
    this.collapsedIcon = const Style(),
  });

  /// Applied to the tree branch characters (`├─`, `└─`, `│ `).
  final Style connector;

  /// Applied to regular (non-selected) node labels.
  final Style label;

  /// Applied to the label of the node under the cursor.
  final Style selectedLabel;

  /// Applied to the expand indicator (`▾`) for nodes with visible children.
  final Style expandedIcon;

  /// Applied to the collapse indicator (`▸`) for collapsed nodes.
  final Style collapsedIcon;

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const TreeStyles defaults = TreeStyles(
    connector: Style(foregroundRgb: RgbColor(88, 91, 112)), // Surface2
    label: Style(foregroundRgb: RgbColor(205, 214, 244)), // Text
    selectedLabel: Style(
      foregroundRgb: RgbColor(30, 30, 46), // Base (dark on accent bg)
      backgroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
    expandedIcon: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
    ),
    collapsedIcon: Style(
      foregroundRgb: RgbColor(166, 173, 200), // Subtext0
    ),
  );
}

// ── Internal flat-list representation ────────────────────────────────────────

/// A single row in the flattened view of the tree.
final class _FlatNode {
  const _FlatNode({
    required this.node,
    required this.depth,
    required this.isLast,
    required this.parentIsLast,
    required this.path, // indices from root → this node
  });

  final TreeNode node;
  final int depth;
  final bool isLast;

  /// For each ancestor, whether it was the last child at its level.
  /// Used to decide whether to draw `│` or ` ` for each prefix column.
  final List<bool> parentIsLast;

  /// Path of child indices from the root to reach this node.
  final List<int> path;
}

// ── TreeModel ─────────────────────────────────────────────────────────────────

/// Hierarchical tree viewer with keyboard-driven expand/collapse.
///
/// Navigation: `↑`/`k` up, `↓`/`j` down, `Enter`/`Space` toggle expand.
/// Press `→`/`l` to expand a collapsed node, `←`/`h` to collapse.
final class TreeModel extends TeaModel {
  TreeModel({
    required this.root,
    this.cursor = 0,
    this.scrollOffset = 0,
    this.height = 20,
    this.styles = TreeStyles.defaults,
    this.viewOffsetY = 0,
  }) : _flat = _buildFlatList(root);

  final TreeNode root;
  final int cursor;
  final int scrollOffset;
  final int height;
  final TreeStyles styles;

  /// Vertical screen offset (rows) of this component's top edge.
  ///
  /// Set by the parent to enable click-to-select mouse handling.
  final int viewOffsetY;

  final List<_FlatNode> _flat;

  int get _safeCursor => cursor.clamp(0, _flat.isEmpty ? 0 : _flat.length - 1);

  /// Total number of currently visible (expanded) nodes in the tree.
  int get nodeCount => _flat.length;

  // ── Flat-list builder ──────────────────────────────────────────────────────

  static List<_FlatNode> _buildFlatList(TreeNode root) {
    final result = <_FlatNode>[];
    // Root is shown as the first row (depth 0)
    result.add(_FlatNode(
      node: root,
      depth: 0,
      isLast: true,
      parentIsLast: const [],
      path: const [],
    ));
    if (root.isExpanded) {
      _addChildren(result, root.children,
          depth: 1, parentIsLast: const [], parentPath: const []);
    }
    return result;
  }

  static void _addChildren(
    List<_FlatNode> result,
    List<TreeNode> children, {
    required int depth,
    required List<bool> parentIsLast,
    required List<int> parentPath,
  }) {
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final isLast = i == children.length - 1;
      final path = [...parentPath, i];
      result.add(_FlatNode(
        node: child,
        depth: depth,
        isLast: isLast,
        parentIsLast: parentIsLast,
        path: path,
      ));
      if (!child.isLeaf && child.isExpanded) {
        _addChildren(
          result,
          child.children,
          depth: depth + 1,
          parentIsLast: [...parentIsLast, isLast],
          parentPath: path,
        );
      }
    }
  }

  // ── Toggle expand/collapse ────────────────────────────────────────────────

  /// Toggle the expanded state of the node at the current cursor position,
  /// returning an updated [TreeModel].
  TreeModel _toggleAtCursor() {
    final cur = _safeCursor;
    if (_flat.isEmpty) return this;
    final flat = _flat[cur];
    if (flat.node.isLeaf) return this;
    final newRoot = _updateNodeAtPath(
        root, flat.path, (n) => n.copyWith(isExpanded: !n.isExpanded));
    return _copyWith(root: newRoot, cursor: cur);
  }

  TreeModel _expandAtCursor() {
    final cur = _safeCursor;
    if (_flat.isEmpty) return this;
    final flat = _flat[cur];
    if (flat.node.isLeaf || flat.node.isExpanded) return this;
    final newRoot =
        _updateNodeAtPath(root, flat.path, (n) => n.copyWith(isExpanded: true));
    return _copyWith(root: newRoot, cursor: cur);
  }

  TreeModel _collapseAtCursor() {
    final cur = _safeCursor;
    if (_flat.isEmpty) return this;
    final flat = _flat[cur];
    if (flat.node.isLeaf || !flat.node.isExpanded) return this;
    final newRoot = _updateNodeAtPath(
        root, flat.path, (n) => n.copyWith(isExpanded: false));
    return _copyWith(root: newRoot, cursor: cur);
  }

  /// Recursively walk [path] through [node]'s child hierarchy, applying
  /// [transform] to the node at the end of the path.
  static TreeNode _updateNodeAtPath(
    TreeNode node,
    List<int> path,
    TreeNode Function(TreeNode) transform,
  ) {
    if (path.isEmpty) return transform(node);
    final idx = path.first;
    final rest = path.sublist(1);
    final newChildren = List<TreeNode>.from(node.children);
    newChildren[idx] = _updateNodeAtPath(newChildren[idx], rest, transform);
    return node.copyWith(children: newChildren);
  }

  TreeModel _moveCursor(int delta) {
    final newCursor = (_safeCursor + delta).clamp(
      0,
      _flat.isEmpty ? 0 : _flat.length - 1,
    );
    var newOffset = scrollOffset;
    if (newCursor < newOffset) newOffset = newCursor;
    if (newCursor >= newOffset + height) newOffset = newCursor - height + 1;
    return _copyWith(cursor: newCursor, scrollOffset: newOffset);
  }

  TreeModel _copyWith({
    TreeNode? root,
    int? cursor,
    int? scrollOffset,
  }) =>
      TreeModel(
        root: root ?? this.root,
        cursor: cursor ?? this.cursor,
        scrollOffset: scrollOffset ?? this.scrollOffset,
        height: height,
        styles: styles,
        viewOffsetY: viewOffsetY,
      );

  // ── TeaModel ──────────────────────────────────────────────────────────────

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is MouseClickMsg) {
      switch (msg.mouse.button) {
        case MouseButton.wheelUp:
          return (_moveCursor(-1), null);
        case MouseButton.wheelDown:
          return (_moveCursor(1), null);
        case MouseButton.left:
          final relY = msg.mouse.y - viewOffsetY;
          final idx = scrollOffset + relY;
          if (idx >= 0 && idx < _flat.length) {
            final moved = _copyWith(
              cursor: idx,
              scrollOffset: scrollOffset,
            );
            return (moved, null);
          }
          return (this, null);
        default:
          return (this, null);
      }
    }
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'up':
      case 'k':
        return (_moveCursor(-1), null);
      case 'down':
      case 'j':
        return (_moveCursor(1), null);
      case 'enter':
      case ' ':
        return (_toggleAtCursor(), null);
      case 'right':
      case 'l':
        return (_expandAtCursor(), null);
      case 'left':
      case 'h':
        return (_collapseAtCursor(), null);
      default:
        return (this, null);
    }
  }

  @override
  View view() {
    final cur = _safeCursor;
    final b = StringBuffer();

    final end = (scrollOffset + height).clamp(0, _flat.length);
    for (var i = scrollOffset; i < end; i++) {
      final flat = _flat[i];
      final node = flat.node;
      final isSelected = i == cur;

      // Build prefix: vertical bars for each ancestor level
      final prefix = StringBuffer();
      if (flat.depth > 0) {
        // Ancestor bars
        for (var d = 0; d < flat.depth - 1; d++) {
          final ancestorIsLast =
              d < flat.parentIsLast.length ? flat.parentIsLast[d] : false;
          prefix.write(styles.connector.render(ancestorIsLast ? '   ' : '│  '));
        }
        // Branch connector for this node
        prefix.write(styles.connector.render(flat.isLast ? '└─ ' : '├─ '));
      }

      // Expand/collapse icon (only for non-leaf nodes)
      String icon = '';
      if (!node.isLeaf) {
        icon = node.isExpanded
            ? '${styles.expandedIcon.render('▾')} '
            : '${styles.collapsedIcon.render('▸')} ';
      }

      // Label
      final labelText = '$icon${node.label}';
      final label = isSelected
          ? styles.selectedLabel.render(labelText)
          : styles.label.render(labelText);

      b.write('$prefix$label');
      if (i < end - 1) b.writeln();
    }

    return newView(b.toString());
  }
}
