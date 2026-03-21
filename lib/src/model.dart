import 'cmd.dart';
import 'msg.dart';
import 'view.dart';

/// Elm-style model: [init], [update], [view].
///
/// Inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea).
abstract class Model {
  /// Optional command to run after the model is first installed.
  Cmd? init() => null;

  /// Handle the next message; return the new model and an optional follow-up command.
  (Model, Cmd?) update(Msg msg);

  /// Render the full program state.
  View view();
}

/// Backwards-compatible alias for previous API name.
typedef TeaModel = Model;

/// Optional model mixin used by prompt-style flows that return a value.
abstract class OutcomeModel<T> implements Model {
  /// When non-null, [Program] stops the loop and returns this value.
  T? get outcome;
}
