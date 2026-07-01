import 'package:characters/characters.dart';

import '../bubbles/file_picker.dart';
import '../bubbles/text_area.dart';
import '../bubbles/text_input.dart';
import '../cmd.dart';
import '../msg.dart';
import 'form_styles.dart';
import 'values.dart';

/// A single field in a [Form]. Immutable — editing returns a new field.
sealed class FormField {
  const FormField();

  /// The result key, or `null` for a [Field.note].
  String? get key;

  /// Whether the field takes keyboard focus (false for notes).
  bool get acceptsInput;

  /// The current typed value (null for notes).
  Object? get value;

  /// The last validation error, or null.
  String? get error;

  /// Whether Enter inserts a newline (true only for multiline text fields).
  bool get isMultiline => false;

  /// Optional command to run when the form starts (e.g. a file field loads a
  /// directory listing).
  Cmd? init() => null;

  bool isHidden(FormValues values);
  String titleText(FormValues values);
  String? descriptionText(FormValues values);

  /// Validate the current value; returns an error message or null.
  String? validate();

  /// Deliver a key to the field's editor, returning the updated field.
  FormField updateEditor(Msg msg);

  /// Refresh dynamic options and clamp selection against [values].
  FormField recompute(FormValues values);

  /// Return a copy carrying [error].
  FormField withError(String? error);

  String render(bool active, FormStyles styles, FormValues values);
}

/// Factory for [FormField]s.
abstract final class Field {
  static FormField input({
    required String key,
    String? title,
    String Function(FormValues)? titleFor,
    String? description,
    String initial = '',
    String placeholder = '',
    String? Function(String value)? validate,
    bool Function(FormValues)? hidden,
  }) =>
      _InputField(
        key: key,
        input: TextInputModel(
            value: initial,
            cursorPos: initial.characters.length,
            placeholder: placeholder,
            focused: true),
        titleSpec: _Title(title, titleFor),
        description: description,
        validator: validate,
        hiddenFn: hidden,
      );

  static FormField password({
    required String key,
    String? title,
    String Function(FormValues)? titleFor,
    String? description,
    String initial = '',
    String? Function(String value)? validate,
    bool Function(FormValues)? hidden,
  }) =>
      _InputField(
        key: key,
        input: TextInputModel(
            value: initial,
            cursorPos: initial.characters.length,
            echoMode: EchoMode.password,
            focused: true),
        titleSpec: _Title(title, titleFor),
        description: description,
        validator: validate,
        hiddenFn: hidden,
      );

  static FormField text({
    required String key,
    String? title,
    String Function(FormValues)? titleFor,
    String? description,
    String initial = '',
    int maxHeight = 6,
    String? Function(String value)? validate,
    bool Function(FormValues)? hidden,
  }) =>
      _TextField(
        key: key,
        area: TextAreaModel(
          value: initial,
          cursorRow: initial.split('\n').length - 1,
          cursorCol: initial.split('\n').last.characters.length,
          maxHeight: maxHeight,
          focused: true,
        ),
        titleSpec: _Title(title, titleFor),
        description: description,
        validator: validate,
        hiddenFn: hidden,
      );

  static FormField file({
    required String key,
    String? title,
    String Function(FormValues)? titleFor,
    String? description,
    String? initialDir,
    Set<String> extensions = const {},
    bool Function(FormValues)? hidden,
  }) =>
      _FileField(
        key: key,
        picker: FilePickerModel(
          currentDir: initialDir ?? '.',
          allowedExtensions: extensions.toList(),
        ),
        titleSpec: _Title(title, titleFor),
        description: description,
        hiddenFn: hidden,
      );

  static FormField note({
    String? title,
    String Function(FormValues)? titleFor,
    String? description,
    bool Function(FormValues)? hidden,
  }) =>
      _NoteField(
        titleSpec: _Title(title, titleFor),
        description: description,
        hiddenFn: hidden,
      );
}

/// Resolves a static or dynamic title.
final class _Title {
  const _Title(this.static, this.fn);
  final String? static;
  final String Function(FormValues)? fn;
  String resolve(FormValues v) => fn?.call(v) ?? static ?? '';
}

/// Shared helpers for the concrete field types.
mixin _FieldCommon on FormField {
  _Title get titleSpec;
  String? get description;
  bool Function(FormValues)? get hiddenFn;

  @override
  bool isHidden(FormValues values) => hiddenFn?.call(values) ?? false;
  @override
  String titleText(FormValues values) => titleSpec.resolve(values);
  @override
  String? descriptionText(FormValues values) => description;
  @override
  FormField recompute(FormValues values) => this; // overridden by select/multi
}

// ── input / password ──────────────────────────────────────────────────────
final class _InputField extends FormField with _FieldCommon {
  const _InputField({
    required this.key,
    required this.input,
    required this.titleSpec,
    required this.description,
    required this.validator,
    required this.hiddenFn,
    this.error,
  });

  @override
  final String? key;
  final TextInputModel input;
  @override
  final _Title titleSpec;
  @override
  final String? description;
  final String? Function(String)? validator;
  @override
  final bool Function(FormValues)? hiddenFn;
  @override
  final String? error;

  @override
  bool get acceptsInput => true;
  @override
  Object? get value => input.value;
  @override
  String? validate() => validator?.call(input.value);

  _InputField _copy({TextInputModel? input, String? error}) => _InputField(
        key: key,
        input: input ?? this.input,
        titleSpec: titleSpec,
        description: description,
        validator: validator,
        hiddenFn: hiddenFn,
        error: error,
      );

  @override
  FormField updateEditor(Msg msg) =>
      _copy(input: input.update(msg).$1 as TextInputModel);
  @override
  FormField withError(String? error) => _copy(error: error);

  @override
  String render(bool active, FormStyles styles, FormValues values) {
    final titleStyle = active ? styles.activeTitle : styles.title;
    final marker = active ? '${styles.cursor.render('›')} ' : '  ';
    final b = StringBuffer('$marker${titleStyle.render(titleText(values))}\n');
    b.write('    ${input.view().content}');
    final d = descriptionText(values);
    if (d != null) b.write('\n    ${styles.description.render(d)}');
    if (error != null) b.write('\n    ${styles.error.render('✗ $error')}');
    return b.toString();
  }
}

// ── text (multiline) ──────────────────────────────────────────────────────
final class _TextField extends FormField with _FieldCommon {
  const _TextField({
    required this.key,
    required this.area,
    required this.titleSpec,
    required this.description,
    required this.validator,
    required this.hiddenFn,
    this.error,
  });

  @override
  final String? key;
  final TextAreaModel area;
  @override
  final _Title titleSpec;
  @override
  final String? description;
  final String? Function(String)? validator;
  @override
  final bool Function(FormValues)? hiddenFn;
  @override
  final String? error;

  @override
  bool get acceptsInput => true;
  @override
  bool get isMultiline => true;
  @override
  Object? get value => area.value;
  @override
  String? validate() => validator?.call(area.value);

  _TextField _copy({TextAreaModel? area, String? error}) => _TextField(
        key: key,
        area: area ?? this.area,
        titleSpec: titleSpec,
        description: description,
        validator: validator,
        hiddenFn: hiddenFn,
        error: error,
      );

  @override
  FormField updateEditor(Msg msg) =>
      _copy(area: area.update(msg).$1 as TextAreaModel);
  @override
  FormField withError(String? error) => _copy(error: error);

  @override
  String render(bool active, FormStyles styles, FormValues values) {
    final titleStyle = active ? styles.activeTitle : styles.title;
    final marker = active ? '${styles.cursor.render('›')} ' : '  ';
    final body =
        area.view().content.split('\n').map((l) => '    $l').join('\n');
    final b =
        StringBuffer('$marker${titleStyle.render(titleText(values))}\n$body');
    if (error != null) b.write('\n    ${styles.error.render('✗ $error')}');
    return b.toString();
  }
}

// ── file ──────────────────────────────────────────────────────────────────
final class _FileField extends FormField with _FieldCommon {
  const _FileField({
    required this.key,
    required this.picker,
    required this.titleSpec,
    required this.description,
    required this.hiddenFn,
    this.error,
  });

  @override
  final String? key;
  final FilePickerModel picker;
  @override
  final _Title titleSpec;
  @override
  final String? description;
  @override
  final bool Function(FormValues)? hiddenFn;
  @override
  final String? error;

  @override
  bool get acceptsInput => true;
  @override
  Object? get value => picker.selected;
  @override
  String? validate() => null;
  @override
  Cmd? init() => picker.init();

  _FileField _copy({FilePickerModel? picker, String? error}) => _FileField(
        key: key,
        picker: picker ?? this.picker,
        titleSpec: titleSpec,
        description: description,
        hiddenFn: hiddenFn,
        error: error,
      );

  @override
  FormField updateEditor(Msg msg) =>
      _copy(picker: picker.update(msg).$1 as FilePickerModel);
  @override
  FormField withError(String? error) => _copy(error: error);

  @override
  String render(bool active, FormStyles styles, FormValues values) {
    final titleStyle = active ? styles.activeTitle : styles.title;
    final marker = active ? '${styles.cursor.render('›')} ' : '  ';
    final b = StringBuffer('$marker${titleStyle.render(titleText(values))}\n');
    b.write(picker.view().content.split('\n').map((l) => '    $l').join('\n'));
    return b.toString();
  }
}

// ── note ──────────────────────────────────────────────────────────────────
final class _NoteField extends FormField with _FieldCommon {
  const _NoteField({
    required this.titleSpec,
    required this.description,
    required this.hiddenFn,
  });

  @override
  final _Title titleSpec;
  @override
  final String? description;
  @override
  final bool Function(FormValues)? hiddenFn;

  @override
  String? get key => null;
  @override
  bool get acceptsInput => false;
  @override
  Object? get value => null;
  @override
  String? get error => null;
  @override
  String? validate() => null;
  @override
  FormField updateEditor(Msg msg) => this;
  @override
  FormField withError(String? error) => this;

  @override
  String render(bool active, FormStyles styles, FormValues values) {
    final b = StringBuffer('  ${styles.activeTitle.render(titleText(values))}');
    final d = descriptionText(values);
    if (d != null) b.write('\n    ${styles.description.render(d)}');
    return b.toString();
  }
}
