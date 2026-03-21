import 'msg.dart';

/// Async side-effect that eventually yields a [Msg] (Bubble Tea `Cmd`).
typedef Cmd = Future<Msg?> Function();

/// Run several commands in parallel; combines their non-null results into one [CompoundMsg].
Cmd batch(List<Cmd> cmds) {
  if (cmds.isEmpty) {
    return () async => null;
  }
  return () async {
    final out = await Future.wait(cmds.map((c) => c()));
    final msgs = out.whereType<Msg>().toList();
    if (msgs.isEmpty) return null;
    if (msgs.length == 1) return msgs.single;
    return CompoundMsg(msgs);
  };
}

/// Run commands one after another; first non-null result wins (rest still run).
Cmd sequence(List<Cmd> cmds) {
  if (cmds.isEmpty) {
    return () async => null;
  }
  return () async {
    for (final c in cmds) {
      final m = await c();
      if (m != null) return m;
    }
    return null;
  };
}

/// Delay before delivering [msg] (e.g. debounce).
Cmd tick(Duration delay, Msg msg) {
  return () async {
    await Future<void>.delayed(delay);
    return msg;
  };
}
