import 'dart:io';

import 'package:path/path.dart' as p;

import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';

/// Internal message: directory listing loaded.
final class _DirLoadedMsg extends Msg {
  _DirLoadedMsg(this.loadState, this.loadToken, this.entries, this.error);
  final _FilePickerLoadState loadState;
  final Object loadToken;
  final List<FileSystemEntity> entries;
  final String? error;
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
    int cursor = 0,
    int scrollOffset = 0,
    int height = 15,
    this.showHidden = false,
    this.allowedExtensions = const [],
    this.selected,
    this.loading = true,
    this.error,
  })  : cursor = cursor.clamp(0, entries.isEmpty ? 0 : entries.length - 1),
        scrollOffset = scrollOffset < 0 ? 0 : scrollOffset,
        height = height < 1 ? 1 : height,
        _loadState = _FilePickerLoadState();

  FilePickerModel._withLoadState({
    required this.currentDir,
    required this.entries,
    required int cursor,
    required int scrollOffset,
    required int height,
    required this.showHidden,
    required this.allowedExtensions,
    required this.selected,
    required this.loading,
    required this.error,
    required _FilePickerLoadState loadState,
  })  : cursor = cursor.clamp(0, entries.isEmpty ? 0 : entries.length - 1),
        scrollOffset = scrollOffset < 0 ? 0 : scrollOffset,
        height = height < 1 ? 1 : height,
        _loadState = loadState;

  final String currentDir;
  final List<FileSystemEntity> entries;
  final int cursor;
  final int scrollOffset;
  final int height;
  final bool showHidden;
  final List<String> allowedExtensions;
  final String? selected;
  final bool loading;
  final String? error;
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
    bool clearSelected = false,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      FilePickerModel._withLoadState(
        currentDir: currentDir ?? this.currentDir,
        entries: entries ?? this.entries,
        cursor: cursor ?? this.cursor,
        scrollOffset: scrollOffset ?? this.scrollOffset,
        height: height ?? this.height,
        showHidden: showHidden ?? this.showHidden,
        allowedExtensions: allowedExtensions ?? this.allowedExtensions,
        selected: clearSelected ? null : (selected ?? this.selected),
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        loadState: currentDir != null && currentDir != this.currentDir ||
                showHidden != null && showHidden != this.showHidden ||
                (allowedExtensions != null &&
                    !_sameStrings(allowedExtensions, this.allowedExtensions))
            ? _FilePickerLoadState()
            : _loadState,
      );

  static bool _sameStrings(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<({List<FileSystemEntity> entries, String? error})> _loadDir(
    String dir,
    bool showHidden,
    List<String> allowedExtensions,
  ) async {
    try {
      final d = Directory(dir);
      if (!await d.exists()) {
        throw FileSystemException('Directory does not exist', dir);
      }
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
      return (entries: all, error: null);
    } on FileSystemException catch (error) {
      return (entries: <FileSystemEntity>[], error: error.message);
    }
  }

  @override
  Cmd? init() {
    final loadToken = Object();
    _loadState.latestToken = loadToken;
    return () async {
      final result = await _loadDir(currentDir, showHidden, allowedExtensions);
      return _DirLoadedMsg(_loadState, loadToken, result.entries, result.error);
    };
  }

  FilePickerModel _moveCursor(int delta) {
    final newCursor =
        (cursor.clamp(0, entries.isEmpty ? 0 : entries.length - 1) + delta)
            .clamp(0, entries.isEmpty ? 0 : entries.length - 1);
    var newOffset = scrollOffset;
    if (newCursor < newOffset) newOffset = newCursor;
    if (newCursor >= newOffset + height) newOffset = newCursor - height + 1;
    return copyWith(cursor: newCursor, scrollOffset: newOffset);
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    switch (msg) {
      case _DirLoadedMsg(
          :final loadState,
          :final loadToken,
          :final entries,
          :final error
        ):
        if (!identical(loadState, _loadState) ||
            !identical(loadToken, _loadState.latestToken)) {
          return (this, null);
        }
        return (
          copyWith(
              entries: entries,
              cursor: 0,
              scrollOffset: 0,
              loading: false,
              error: error,
              clearError: error == null),
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
            final entry = entries[cursor.clamp(0, entries.length - 1)];
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

    if (error != null) {
      b.write('Unable to load directory: $error');
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
