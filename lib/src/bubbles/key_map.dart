import '../msg.dart';
import 'help.dart';

/// A single bindable key action.
final class KeyBinding {
  const KeyBinding({
    required this.keys,
    required this.help,
    this.enabled = true,
  });

  /// List of keystroke strings that trigger this action, e.g. `['q', 'ctrl+c']`.
  final List<String> keys;

  /// Short description shown in the help view.
  final HelpEntry help;

  /// Whether this binding is active.
  final bool enabled;

  /// Returns true when [msg] matches one of the bound keys and the binding
  /// is enabled.
  bool matches(KeyMsg msg) => enabled && keys.contains(msg.key);

  /// Return a copy with [enabled] changed.
  KeyBinding withEnabled(bool value) =>
      KeyBinding(keys: keys, help: help, enabled: value);
}

/// A group of bindings used with [HelpModel.fromKeyMap].
abstract class KeyMap {
  List<KeyBinding> get bindings;
}
