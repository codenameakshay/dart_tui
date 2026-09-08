import 'dart:io';

import 'package:path/path.dart' as p;

import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';

/// Internal message: directory listing loaded.
final class _DirLoadedMsg extends Msg {
  _DirLoadedMsg(this.loadState, this.loadToken, this.entries);
  final _FilePickerLoadState loadState;
  final Object loadToken;
  final List<FileSystemEntity> entries;
}

final class _FilePickerLoadState {
  Object? latestToken;
}

/// Filesystem browser bubble.
///
/// On [init], loads the entries of [currentDir]. Navigation keys change the
/// directory or set [selected] to the chosen file path.
final class FilePickerModel extends Model {
  FilePickerModel({
    required this.currentDir,
    this.entries = const [],
    this.cursor = 0,
    this.scrollOffset = 0,
    this.height = 15,
    this.showHidden = false,
    this.allowedExtensions = const [],
    this.selected,
    this.loading = true,
  }) : _loadState = _FilePickerLoadState();

  FilePickerModel._withLoadState({
    required this.currentDir,
    required this.entries,
    required this.cursor,
    required this.scrollOffset,
    required this.height,
    required this.showHidden,
    required this.allowedExtensions,
    required this.selected,
    required this.loading,
    required _FilePickerLoadState loadState,
  }) : _loadState = loadState;

  final String currentDir;
  final List<FileSystemEntity> entries;
  final int cursor;
  final int scrollOffset;
  final int height;
  final bool showHidden;
  final List<String> allowedExtensions;
  final String? selected;
  final bool loading;
  final _FilePickerLoadState _loadState;

  FilePickerModel copyWith({
    String? currentDir,
    List<FileSystemEntity>? entries,
    int? cursor,
    int? scrollOffset,
    int? height,
    bool? showHidden,
    List<String>? allowedExtensions,
    String? selected,
    bool? loading,
  }) =>
      FilePickerModel._withLoadState(
        currentDir: currentDir ?? this.currentDir,
        entries: entries ?? this.entries,
        cursor: cursor ?? this.cursor,
        scrollOffset: scrollOffset ?? this.scrollOffset,
        height: height ?? this.height,
        showHidden: showHidden ?? this.showHidden,
        allowedExtensions: allowedExtensions ?? this.allowedExtensions,
        selected: selected ?? this.selected,
        loading: loading ?? this.loading,
        loadState: currentDir != null && currentDir != this.currentDir ||
                showHidden != null && showHidden != this.showHidden ||
                allowedExtensions != null
            ? _FilePickerLoadState()
            : _loadState,
      );

  static Future<List<FileSystemEntity>> _loadDir(
    String dir,
    bool showHidden,
    List<String> allowedExtensions,
  ) async {
    try {
      final d = Directory(dir);
      if (!await d.exists()) return [];
      final all = (await d.list().toList()).where((e) {
        final name = p.basename(e.path);
        if (!showHidden && name.startsWith('.')) return false;
        if (e is File && allowedExtensions.isNotEmpty) {
          final ext = p.extension(e.path).toLowerCase();
          return allowedExtensions.contains(ext);
        }
        return true;
      }).toList()
        ..sort((a, b) {
          final aIsDir = a is Directory ? 0 : 1;
          final bIsDir = b is Directory ? 0 : 1;
          if (aIsDir != bIsDir) return aIsDir - bIsDir;
          return p.basename(a.path).compareTo(p.basename(b.path));
        });
      return all;
    } catch (_) {
      return [];
    }
  }

  @override
  Cmd? init() {
    final loadToken = Object();
    _loadState.latestToken = loadToken;
    return () async {
      final loaded = await _loadDir(currentDir, showHidden, allowedExtensions);
      return _DirLoadedMsg(_loadState, loadToken, loaded);
    };
  }

  FilePickerModel _moveCursor(int delta) {
    final newCursor =
        (cursor + delta).clamp(0, entries.isEmpty ? 0 : entries.length - 1);
    var newOffset = scrollOffset;
    if (newCursor < newOffset) newOffset = newCursor;
    if (newCursor >= newOffset + height) newOffset = newCursor - height + 1;
    return copyWith(cursor: newCursor, scrollOffset: newOffset);
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    switch (msg) {
      case _DirLoadedMsg(:final loadState, :final loadToken, :final entries):
        if (!identical(loadState, _loadState) ||
            !identical(loadToken, _loadState.latestToken)) {
          return (this, null);
        }
        return (
          copyWith(
              entries: entries, cursor: 0, scrollOffset: 0, loading: false),
          null
        );

      case KeyMsg():
        switch (msg.key) {
          case 'up':
          case 'k':
            return (_moveCursor(-1), null);

          case 'down':
          case 'j':
            return (_moveCursor(1), null);

          case 'enter':
          case 'right':
            if (entries.isEmpty) return (this, null);
            final entry = entries[cursor];
            if (entry is Directory) {
              final next = copyWith(
                currentDir: entry.path,
                loading: true,
              );
              return (next, next.init());
            } else {
              return (copyWith(selected: entry.path), null);
            }

          case 'backspace':
          case 'left':
            final parent = p.dirname(currentDir);
            if (parent == currentDir) return (this, null); // at root
            final next = copyWith(
              currentDir: parent,
              loading: true,
            );
            return (next, next.init());

          case 'h':
            final next = copyWith(showHidden: !showHidden, loading: true);
            return (next, next.init());

          default:
            return (this, null);
        }

      default:
        return (this, null);
    }
  }

  @override
  View view() {
    final b = StringBuffer();
    b.writeln(currentDir);
    b.writeln('─' * 40);

    if (loading) {
      b.write('Loading...');
      return newView(b.toString());
    }

    if (entries.isEmpty) {
      b.writeln('(empty)');
    } else {
      final end = (scrollOffset + height).clamp(0, entries.length);
      for (var i = scrollOffset; i < end; i++) {
        final entry = entries[i];
        final name = p.basename(entry.path);
        final tag = entry is Directory ? '[dir] ' : '[file]';
        final pointer = i == cursor ? '>' : ' ';
        b.write('$pointer $tag $name');
        if (i < end - 1) b.writeln();
      }
    }

    b.writeln();
    b.writeln('─' * 40);
    b.write('↑↓ navigate · Enter open · ← parent · Esc cancel');
    return newView(b.toString());
  }
}
