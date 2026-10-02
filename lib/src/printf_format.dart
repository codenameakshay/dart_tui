/// Applies the package's `%s`-only formatting convention.
String formatPrintf(String template, List<Object?> args) {
  var output = template;
  for (final argument in args) {
    output = output.replaceFirst('%s', '$argument');
  }
  return output;
}
