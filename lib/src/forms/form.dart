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
final class Form extends Model implements OutcomeModel<FormValues> {
  Form(this.groups, {this.styles = FormStyles.defaults})
      : groupIndex = 0,
        fieldIndex = 0,
        submitted = false,
        cancelled = false {
    final keys = <String>{};
    if (groups.isEmpty) {
      throw ArgumentError('a Form needs at least one group');
    }
    for (final g in groups) {
      if (g.fields.isEmpty) {
        throw ArgumentError('a Form group needs at least one field');
      }
      for (final f in g.fields) {
        final k = f.key;
        if (k != null && !keys.add(k)) {
          throw ArgumentError('duplicate field key: $k');
        }
      }
    }
  }

  Form._(this.groups, this.styles, this.groupIndex, this.fieldIndex,
      this.submitted, this.cancelled);

  final List<Group> groups;
  final FormStyles styles;
  final int groupIndex;
  final int fieldIndex;
  final bool submitted;
  final bool cancelled;

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
  FormValues get values {
    final rv = _rawValues;
    final out = <String, Object?>{};
    for (final g in groups) {
      if (g.hidden?.call(rv) ?? false) continue;
      for (final f in g.fields) {
        final k = f.key;
        if (k != null && !f.isHidden(rv)) out[k] = f.value;
      }
    }
    return FormValues(out);
  }

  /// Values of every keyed field including hidden ones — drives
  /// `hidden()` / `optionsFor()` / `recompute()`. The public [values] filters
  /// hidden fields out (Decision B).
  FormValues get _rawValues {
    final raw = <String, Object?>{};
    for (final g in groups) {
      for (final f in g.fields) {
        if (f.key != null) raw[f.key!] = f.value;
      }
    }
    return FormValues(raw);
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
  Future<FormValues?> run({List<ProgramOption> options = const []}) async {
    final result = await Program(options: options).run(_FormRunner(this));
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

  List<int> _visibleGroups(FormValues values) => [
        for (var i = 0; i < groups.length; i++)
          if (!(groups[i].hidden?.call(values) ?? false)) i
      ];

  int? _firstFocusable(int gi, FormValues values) {
    final t = _focusable(groups[gi], values);
    return t.isEmpty ? null : t.first;
  }

  int? _lastFocusable(int gi, FormValues values) {
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

  Form _normalizeFocus() {
    final values = _rawValues;
    final active = groups[groupIndex].fields[fieldIndex];
    final groupVisible = !(groups[groupIndex].hidden?.call(values) ?? false);
    if (groupVisible && active.acceptsInput && !active.isHidden(values)) {
      return this;
    }

    final visible = _visibleGroups(values);
    if (groupVisible) {
      final sameGroup =
          _focusable(groups[groupIndex], values).where((i) => i > fieldIndex);
      if (sameGroup.isNotEmpty) return _copy(fieldIndex: sameGroup.first);
    }
    for (final gi in visible.where((i) => i > groupIndex)) {
      final field = _firstFocusable(gi, values);
      if (field != null) return _copy(groupIndex: gi, fieldIndex: field);
    }
    for (final gi in visible.where((i) => i < groupIndex).toList().reversed) {
      final field = _lastFocusable(gi, values);
      if (field != null) return _copy(groupIndex: gi, fieldIndex: field);
    }
    if (groupVisible) {
      final remaining = _focusable(groups[groupIndex], values);
      if (remaining.isNotEmpty) return _copy(fieldIndex: remaining.last);
    }
    return this;
  }

  (Model, Cmd?) _advance() {
    var current = _normalizeFocus();
    final active =
        current.groups[current.groupIndex].fields[current.fieldIndex];
    final values = current._rawValues;
    final groupVisible =
        !(current.groups[current.groupIndex].hidden?.call(values) ?? false);
    if (groupVisible && active.acceptsInput && !active.isHidden(values)) {
      final err = active.validate();
      if (err != null) return (current._setActiveError(err), null);
      if (active.error != null) current = current._setActiveError(null);
    }

    final nextValues = current._rawValues;
    final visible = current._visibleGroups(nextValues);
    final currentPosition = visible.indexOf(current.groupIndex);
    final sameGroup = groupVisible
        ? current
            ._focusable(current.groups[current.groupIndex], nextValues)
            .where((i) => i > current.fieldIndex)
        : const <int>[];
    if (sameGroup.isNotEmpty) {
      return (current._copy(fieldIndex: sameGroup.first), null);
    }
    for (var i = currentPosition + 1; i < visible.length; i++) {
      final gi = visible[i];
      final field = current._firstFocusable(gi, nextValues);
      if (field != null) {
        return (current._copy(groupIndex: gi, fieldIndex: field), null);
      }
    }
    return current._submit();
  }

  // Validate every visible keyed field; jump to the first error, else submit.
  (Model, Cmd?) _submit() {
    final rv = _rawValues;
    for (var gi = 0; gi < groups.length; gi++) {
      final g = groups[gi];
      if (g.hidden?.call(rv) ?? false) continue;
      for (var fi = 0; fi < g.fields.length; fi++) {
        final f = g.fields[fi];
        if (f.isHidden(rv)) continue;
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
    final values = _rawValues;
    final targets = _focusable(groups[groupIndex], values);
    final pos = targets.indexOf(fieldIndex);
    if (pos > 0) return (_copy(fieldIndex: targets[pos - 1]), null);
    // before the first field of this group → previous visible group's last field
    final vg = _visibleGroups(values);
    final gp = vg.indexOf(groupIndex);
    for (var j = gp - 1; j >= 0; j--) {
      final lf = _lastFocusable(vg[j], values);
      if (lf != null) return (_copy(groupIndex: vg[j], fieldIndex: lf), null);
    }
    return (this, null); // no-op at the very first field
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (_broadcast(msg), null);
    final current = _normalizeFocus();
    final active =
        current.groups[current.groupIndex].fields[current.fieldIndex];
    final multiline = active.isMultiline;
    switch (msg.key) {
      case 'esc':
      case 'ctrl+c':
        return (current._copy(cancelled: true), null);
      case 'ctrl+d':
      case 'tab':
        return _advance();
      case 'shift+tab':
        return current._back();
      case 'enter':
        if (!multiline) return _advance();
    }
    // delegate to the active field's editor, then recompute dynamics
    final values = current._rawValues;
    if ((current.groups[current.groupIndex].hidden?.call(values) ?? false) ||
        !active.acceptsInput ||
        active.isHidden(values)) {
      return (current, null);
    }
    final g0 = current.groups[current.groupIndex];
    final edited = [...g0.fields];
    edited[current.fieldIndex] = active.updateEditor(msg);
    var nf = current._withGroups([
      for (var i = 0; i < current.groups.length; i++)
        if (i == current.groupIndex)
          Group(edited, title: g0.title, hidden: g0.hidden)
        else
          current.groups[i],
    ]);

    // recompute dynamic options/selection against the new raw values
    final rv = nf._rawValues;
    nf = nf._withGroups([
      for (final g in nf.groups)
        Group([for (final f in g.fields) f.recompute(rv)],
            title: g.title, hidden: g.hidden),
    ]);

    return (nf._normalizeFocus(), null);
  }

  @override
  View view() {
    final v = _rawValues;
    final visible = _visibleGroups(v);
    final currentGroupIsVisible = visible.contains(groupIndex);
    final displayGroupIndex = currentGroupIsVisible
        ? groupIndex
        : visible.isEmpty
            ? groupIndex
            : visible.first;
    final g = groups[displayGroupIndex];
    final b = StringBuffer();
    if (visible.length > 1) {
      final pos = visible.indexOf(displayGroupIndex) + 1;
      b.writeln(styles.pageIndicator
          .render('${g.title ?? 'Step'}  $pos/${visible.length}'));
    } else if (g.title != null) {
      b.writeln(styles.activeTitle.render(g.title!));
    }
    if (visible.contains(displayGroupIndex)) {
      for (var i = 0; i < g.fields.length; i++) {
        if (g.fields[i].isHidden(v)) continue;
        b.writeln(g.fields[i].render(
            displayGroupIndex == groupIndex && i == fieldIndex, styles, v));
      }
    }
    b.write(styles.help
        .render('tab next · shift+tab back · enter submit · esc cancel'));
    return newView(b.toString());
  }
}

/// Wraps a [Form] so `run()` quits on submit or cancel without the `Form`
/// itself issuing a quit — keeping it safely embeddable in a larger model.
final class _FormRunner extends Model {
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
