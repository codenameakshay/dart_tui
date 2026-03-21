/// Terminal events and application messages (Bubble Tea–style).
sealed class Msg {}

/// A key chord in Bubble Tea string form, e.g. `up`, `down`, `enter`, `ctrl+c`, `a`.
final class KeyMsg extends Msg {
  KeyMsg(this.key);

  final String key;

  @override
  String toString() => 'KeyMsg($key)';
}

/// Terminal size changed (e.g. SIGWINCH).
final class WindowSizeMsg extends Msg {
  WindowSizeMsg(this.width, this.height);

  final int width;
  final int height;
}

/// Periodic tick for animations (spinners, etc.).
final class TickMsg extends Msg {
  TickMsg(this.when);

  final DateTime when;
}

/// Multiple messages produced by [batch] — processed in order by [Program].
final class CompoundMsg extends Msg {
  CompoundMsg(this.msgs);

  final List<Msg> msgs;
}

/// Stop the [Program] loop (typically scheduled from a [Cmd] or after a key binding).
final class QuitMsg extends Msg {}
