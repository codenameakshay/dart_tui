part of 'program.dart';

// Service extensions for `dart_tui dev` (hot reload). Each isolate registers
// them once, and only when its VM service is running, so release builds and
// normal runs never register anything.

/// The programs that are running now; `ext.dart_tui.reassemble` redraws them.
final Set<Program> _livePrograms = {};

/// The `ext.dart_tui.devStatus` banner, or null when there is none.
String? _devBanner;

Future<void>? _devExtensions;

Future<Uri?> Function() _devServiceUri = _vmServiceUri;
void Function(String method, ServiceExtensionHandler handler) _devRegister =
    registerExtension;

Future<Uri?> _vmServiceUri() async => (await Service.getInfo()).serverUri;

/// Internal, for tests: replaces how programs find the VM service and register
/// extensions, and forgets an earlier registration and banner.
void setDevHooksForTesting({
  Future<Uri?> Function()? serviceUri,
  void Function(String method, ServiceExtensionHandler handler)? register,
}) {
  _devServiceUri = serviceUri ?? _vmServiceUri;
  _devRegister = register ?? registerExtension;
  _devExtensions = null;
  _devBanner = null;
}

/// Sent to each live program to redraw it after a reload or a banner change.
final class _DevRedrawMsg extends Msg {
  const _DevRedrawMsg();
}

void _registerDevExtensions() {
  if (const bool.fromEnvironment('dart.vm.product')) return;
  _devExtensions ??= () async {
    try {
      if (await _devServiceUri() == null) return;
      _devRegister('ext.dart_tui.reassemble', (_, __) async {
        final programs = _redrawLivePrograms();
        return ServiceExtensionResponse.result(
            jsonEncode({'programs': programs}));
      });
      _devRegister('ext.dart_tui.devStatus', (_, params) async {
        final text = params['text'];
        _devBanner = text == null || text.isEmpty ? null : text;
        _redrawLivePrograms();
        return ServiceExtensionResponse.result('{}');
      });
    } catch (_) {
      // No service info (or an embedder without extensions): dev mode is off.
    }
  }();
}

int _redrawLivePrograms() {
  for (final program in [..._livePrograms]) {
    program.send(const _DevRedrawMsg());
  }
  return _livePrograms.length;
}

/// [view] with the dev banner as its last line, or [view] itself without one.
/// In a full alternate screen the banner replaces the bottom row.
View _withDevBanner(View view, {required int width, int? height}) {
  final banner = _devBanner;
  if (banner == null) return view;
  var lines = view.content.split('\n');
  if (height != null && height > 0 && lines.length >= height) {
    lines = lines.sublist(0, height - 1);
  }
  final text = truncate(banner.replaceAll('\n', ' '), width - 2);
  lines.add(const Style(isBold: true, isReverse: true).render(' $text '));
  return View(
    content: lines.join('\n'),
    onMouse: view.onMouse,
    cursor: view.cursor,
    backgroundColor: view.backgroundColor,
    foregroundColor: view.foregroundColor,
    windowTitle: view.windowTitle,
    progressBar: view.progressBar,
    altScreen: view.altScreen,
    reportFocus: view.reportFocus,
    disableBracketedPasteMode: view.disableBracketedPasteMode,
    mouseMode: view.mouseMode,
    keyboardEnhancements: view.keyboardEnhancements,
  );
}
