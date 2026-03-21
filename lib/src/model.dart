import 'cmd.dart';
import 'msg.dart';

/// Elm-style model: [init], [update], [view].
///
/// Inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea).
abstract class TeaModel {
  /// Optional command to run after the model is first installed.
  Cmd? init() => null;

  /// Handle the next message; return the new model and an optional follow-up command.
  (TeaModel, Cmd?) update(Msg msg);

  /// Render the full screen as a string (newline-terminated lines).
  String view();

  /// When `true`, [Program] exits the loop after the current frame.
  bool get quit => false;
}

/// A model that can signal completion with a value (used by [Program.runForResult]).
abstract class OutcomeModel<T> implements TeaModel {
  /// When non-null, [Program] stops the loop and returns this value.
  T? get outcome;
}
