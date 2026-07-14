import '../bubbles/style.dart';

/// Styling for a [Form] and its fields. Catppuccin Mocha defaults.
final class FormStyles {
  const FormStyles({
    this.title = const Style(),
    this.activeTitle = const Style(),
    this.description = const Style(),
    this.error = const Style(),
    this.cursor = const Style(),
    this.option = const Style(),
    this.selectedOption = const Style(),
    this.checkedBox = const Style(),
    this.uncheckedBox = const Style(),
    this.help = const Style(),
    this.pageIndicator = const Style(),
  });

  final Style title; // inactive field title
  final Style activeTitle; // focused field title
  final Style description; // field description / note body
  final Style error; // inline validation error
  final Style cursor; // focus marker (›)
  final Style option; // unselected option
  final Style selectedOption; // highlighted / chosen option
  final Style checkedBox; // [x]
  final Style uncheckedBox; // [ ]
  final Style help; // footer help line
  final Style pageIndicator; // Group N/M

  static const FormStyles defaults = FormStyles(
    title: Style(foregroundRgb: RgbColor(205, 214, 244)),
    activeTitle: Style(foregroundRgb: RgbColor(203, 166, 247), isBold: true),
    description: Style(foregroundRgb: RgbColor(166, 173, 200), isDim: true),
    error: Style(foregroundRgb: RgbColor(243, 139, 168)),
    cursor: Style(foregroundRgb: RgbColor(203, 166, 247), isBold: true),
    option: Style(foregroundRgb: RgbColor(205, 214, 244)),
    selectedOption: Style(foregroundRgb: RgbColor(166, 227, 161), isBold: true),
    checkedBox: Style(foregroundRgb: RgbColor(166, 227, 161)),
    uncheckedBox: Style(foregroundRgb: RgbColor(108, 112, 134)),
    help: Style(foregroundRgb: RgbColor(108, 112, 134), isDim: true),
    pageIndicator: Style(foregroundRgb: RgbColor(137, 180, 250), isBold: true),
  );
}
