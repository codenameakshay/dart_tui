/// The typed values collected by a [Form], keyed by each field's `key`.
final class FormValues {
  const FormValues(this._map);
  final Map<String, Object?> _map;

  /// The value for [key] cast to [T], or `null` if absent.
  T? get<T>(String key) => _map[key] as T?;

  /// Whether [key] has a value (i.e. a visible, keyed field produced it).
  bool has(String key) => _map.containsKey(key);

  /// An unmodifiable copy of the underlying map.
  Map<String, Object?> toMap() => Map<String, Object?>.unmodifiable(_map);

  /// An empty value set.
  static const FormValues empty = FormValues({});
}

/// A selectable option: a display [label] and its typed [value].
final class Option<T> {
  const Option(this.label, this.value);
  final String label;
  final T value;
}
