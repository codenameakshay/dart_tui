import 'package:meta/meta.dart';

import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../program.dart';
import '../view.dart';
import 'field.dart';
import 'form_styles.dart';
import 'values.dart';

/// A page of [FormField]s within a [Form].
final class Group {
  Group(this.fields, {this.title, this.hidden});
  final List<FormField> fields;
  final String? title;
  final bool Function(FormValues)? hidden;
}

/// An immutable, key-based, huh-style form.
final class Form extends TeaModel implements OutcomeModel<FormValues> {
  Form(this.groups, {this.styles = FormStyles.defaults})
      : groupIndex = 0,
        fieldIndex = 0,
        submitted = false,
        cancelled = false {
    final keys = <String>{};
    for (final g in groups) {
      for (final f in g.fields) {
        final k = f.key;
        assert(k == null || keys.add(k), 'duplicate field key: $k');
      }
    }
    assert(groups.isNotEmpty, 'a Form needs at least one group');
  }

  Form._(this.groups, this.styles, this.groupIndex, this.fieldIndex,
      this.submitted, this.cancelled);

  final List<Group> groups;
  final FormStyles styles;
  final int groupIndex;
  final int fieldIndex;
  final bool submitted;
  final bool cancelled;

  @visibleForTesting
  int get fieldIndexForTest => fieldIndex;

  Form _copy(
          {int? groupIndex,
          int? fieldIndex,
          bool? submitted,
          bool? cancelled}) =>
      Form._(
        groups,
        styles,
        groupIndex ?? this.groupIndex,
        fieldIndex ?? this.fieldIndex,
        submitted ?? this.submitted,
        cancelled ?? this.cancelled,
      );

  Form _withGroups(List<Group> next) =>
      Form._(next, styles, groupIndex, fieldIndex, submitted, cancelled);

  /// The values of every visible, keyed field (hidden fields excluded).
  ///
  /// (Task 9 replaces the hidden resolution with live values.)
  FormValues get values {
    final map = <String, Object?>{};
    for (final g in groups) {
      if (g.hidden?.call(const FormValues({})) ?? false) continue;
      for (final f in g.fields) {
        final k = f.key;
        if (k != null && !f.isHidden(const FormValues({}))) map[k] = f.value;
      }
    }
    return FormValues(map);
  }

  @override
  FormValues? get outcome => submitted ? values : null;

  @override
  Cmd? init() {
    final cmds = <Cmd?>[];
    for (final g in groups) {
      for (final f in g.fields) {
        cmds.add(f.init());
      }
    }
    return batch(cmds);
  }

  /// Run the form as a one-shot program; returns the values, or `null` if
  /// cancelled. Safe to call from a script.
  Future<FormValues?> run({
    ProgramOptions programSettings = const ProgramOptions(),
    List<ProgramOption> programOptions = const [],
  }) async {
    final result =
        await Program(options: programSettings, programOptions: programOptions)
            .run(_FormRunner(this));
    final f = (result as _FormRunner).form;
    return f.submitted ? f.values : null;
  }

  /// Deliver a non-key message (file-picker loads, ticks) to every field.
  Form _broadcast(Msg msg) {
    final next = [
      for (final g in groups)
        Group([for (final f in g.fields) f.updateEditor(msg)],
            title: g.title, hidden: g.hidden),
    ];
    return _withGroups(next);
  }

  // Focus targets in a group, given current values.
  List<int> _focusable(Group g, FormValues v) => [
        for (var i = 0; i < g.fields.length; i++)
          if (g.fields[i].acceptsInput && !g.fields[i].isHidden(v)) i,
      ];

  List<int> _visibleGroups() => [
        for (var i = 0; i < groups.length; i++)
          if (!(groups[i].hidden?.call(values) ?? false)) i
      ];

  int? _firstFocusable(int gi) {
    final t = _focusable(groups[gi], values);
    return t.isEmpty ? null : t.first;
  }

  int? _lastFocusable(int gi) {
    final t = _focusable(groups[gi], values);
    return t.isEmpty ? null : t.last;
  }

  Form _setActiveError(String? error) {
    final g = groups[groupIndex];
    final fields = [...g.fields];
    fields[fieldIndex] = fields[fieldIndex].withError(error);
    final next = [...groups];
    next[groupIndex] = Group(fields, title: g.title, hidden: g.hidden);
    return _withGroups(next);
  }

  (Model, Cmd?) _advance() {
    final active = groups[groupIndex].fields[fieldIndex];
    final err = active.validate();
    if (err != null) return (_setActiveError(err), null); // blocked
    final cleared = active.error == null ? this : _setActiveError(null);

    final g = cleared.groups[cleared.groupIndex];
    final targets = cleared._focusable(g, cleared.values);
    final pos = targets.indexOf(cleared.fieldIndex);
    if (pos >= 0 && pos < targets.length - 1) {
      return (cleared._copy(fieldIndex: targets[pos + 1]), null);
    }
    // past the last focusable field of this group → next visible group
    final vg = cleared._visibleGroups();
    final gp = vg.indexOf(cleared.groupIndex);
    if (gp + 1 < vg.length) {
      final gi = vg[gp + 1];
      final ff = cleared._firstFocusable(gi);
      return (cleared._copy(groupIndex: gi, fieldIndex: ff ?? 0), null);
    }
    return cleared._submit();
  }

  // Validate every visible keyed field; jump to the first error, else submit.
  (Model, Cmd?) _submit() {
    for (var gi = 0; gi < groups.length; gi++) {
      final g = groups[gi];
      if (g.hidden?.call(values) ?? false) continue;
      for (var fi = 0; fi < g.fields.length; fi++) {
        final f = g.fields[fi];
        if (f.isHidden(values)) continue;
        final err = f.validate();
        if (err != null) {
          return (
            _copy(groupIndex: gi, fieldIndex: fi)._setActiveError(err),
            null,
          );
        }
      }
    }
    return (_copy(submitted: true), null);
  }

  (Model, Cmd?) _back() {
    final targets = _focusable(groups[groupIndex], values);
    final pos = targets.indexOf(fieldIndex);
    if (pos > 0) return (_copy(fieldIndex: targets[pos - 1]), null);
    // before the first field of this group → previous visible group's last field
    final vg = _visibleGroups();
    final gp = vg.indexOf(groupIndex);
    for (var j = gp - 1; j >= 0; j--) {
      final lf = _lastFocusable(vg[j]);
      if (lf != null) return (_copy(groupIndex: vg[j], fieldIndex: lf), null);
    }
    return (this, null); // no-op at the very first field
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (_broadcast(msg), null);
    final active = groups[groupIndex].fields[fieldIndex];
    final multiline = active.isMultiline;
    switch (msg.key) {
      case 'esc':
      case 'ctrl+c':
        return (_copy(cancelled: true), null);
      case 'ctrl+d':
      case 'tab':
        return _advance();
      case 'shift+tab':
        return _back();
      case 'enter':
        if (!multiline) return _advance();
    }
    // delegate to the active field's editor
    final g = groups[groupIndex];
    final fields = [...g.fields];
    fields[fieldIndex] = active.updateEditor(msg);
    final next = [...groups];
    next[groupIndex] = Group(fields, title: g.title, hidden: g.hidden);
    return (_withGroups(next), null);
  }

  @override
  View view() {
    final g = groups[groupIndex];
    final v = values;
    final b = StringBuffer();
    final visible = _visibleGroups();
    if (visible.length > 1) {
      final pos = visible.indexOf(groupIndex) + 1;
      b.writeln(styles.pageIndicator
          .render('${g.title ?? 'Step'}  $pos/${visible.length}'));
    } else if (g.title != null) {
      b.writeln(styles.activeTitle.render(g.title!));
    }
    for (var i = 0; i < g.fields.length; i++) {
      b.writeln(g.fields[i].render(i == fieldIndex, styles, v));
    }
    b.write(styles.help
        .render('tab next · shift+tab back · enter submit · esc cancel'));
    return newView(b.toString());
  }
}

/// Wraps a [Form] so `run()` quits on submit or cancel without the `Form`
/// itself issuing a quit — keeping it safely embeddable in a larger model.
final class _FormRunner extends TeaModel {
  _FormRunner(this.form);
  final Form form;

  @override
  Cmd? init() => form.init();

  @override
  (Model, Cmd?) update(Msg msg) {
    final (m, cmd) = form.update(msg);
    final next = m as Form;
    if (next.submitted || next.cancelled) {
      return (_FormRunner(next), () => QuitMsg());
    }
    return (_FormRunner(next), cmd);
  }

  @override
  View view() => form.view();
}
