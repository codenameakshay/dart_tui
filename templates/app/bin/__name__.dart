import 'package:__name__/__name__.dart';
import 'package:dart_tui/dart_tui.dart';

/// Runs the app on the alternate screen, which is restored when it quits.
Future<void> main() async {
  await Program(options: [withAltScreen()]).run(AppModel());
}
