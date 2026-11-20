// `dart pub global activate dart_tui`, then `dart_tui create`.
import 'package:dart_tui/src/create/create.dart';

Future<void> main(List<String> args) => DartTuiRunner().runAndExit(args);
