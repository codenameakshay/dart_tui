import 'package:characters/characters.dart';

import '../msg.dart';

/// Horizontal text alignment.
enum Align { left, center, right }

/// Vertical content alignment (used when [Style.height] is set, or in
/// [joinHorizontal]).
enum AlignVertical { top, middle, bottom }

// ── AlignVertical → double helper ─────────────────────────────────────────────

extension AlignVerticalDouble on AlignVertical {
  /// Returns the equivalent fractional position (0.0 = top, 0.5 = mid, 1.0 = bottom).
  double get fraction => switch (this) {
        AlignVertical.top => 0.0,
        AlignVertical.middle => 0.5,
        AlignVertical.bottom => 1.0,
      };
}

extension AlignDouble on Align {
  /// Returns the equivalent fractional position (0.0 = left, 0.5 = center, 1.0 = right).
  double get fraction => switch (this) {
        Align.left => 0.0,
        Align.center => 0.5,
        Align.right => 1.0,
      };
}

/// Composable ANSI style object inspired by Lip Gloss primitives.
///
/// All properties default to "unset" (null for optionals, false for booleans).
/// Call [inherit] to fill in unset properties from a parent style.
final class Style {
  const Style({
    this.foreground256,
    this.background256,
    this.foregroundRgb,
    this.backgroundRgb,
    this.foregroundComplete,
    this.backgroundComplete,
    this.adaptiveForeground,
    this.adaptiveBackground,
    this.isBold,
    this.isDim,
    this.isItalic,
    this.isUnderline,
    this.isStrikethrough,
    this.isReverse,
    this.isBlink,
    this.isOverline,
    this.underlineSpaces = true,
    this.strikethroughSpaces = true,
    this.padding = const EdgeInsets.all(0),
    this.margin = const EdgeInsets.all(0),
    this.border = Border.none,
    this.borderForeground,
    this.borderBackground,
    this.borderTitle = '',
    this.borderTitleAlignment = Align.left,
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.align = Align.left,
    this.alignVertical = AlignVertical.top,
    this.inline = false,
    this.wordWrap = false,
    this.profile,
    this.transform,
  });

  final int? foreground256;
  final int? background256;
  final RgbColor? foregroundRgb;
  final RgbColor? backgroundRgb;

  /// A [CompleteColor] lets you specify different color values for each
  /// terminal color profile (trueColor, ansi256, ansi16). When set, takes
  /// precedence over [foregroundRgb] and [foreground256].
  final CompleteColor? foregroundComplete;

  /// A [CompleteColor] for the background.
  final CompleteColor? backgroundComplete;

  final AdaptiveColor? adaptiveForeground;
  final AdaptiveColor? adaptiveBackground;

  /// SGR 1 — bold / increased intensity. `null` = unset (inheritable).
  final bool? isBold;

  /// SGR 2 — faint / decreased intensity. `null` = unset (inheritable).
  final bool? isDim;

  /// SGR 3 — italic. `null` = unset (inheritable).
  final bool? isItalic;

  /// SGR 4 — underline. `null` = unset (inheritable).
  final bool? isUnderline;

  /// SGR 9 — crossed-out / strikethrough. `null` = unset (inheritable).
  final bool? isStrikethrough;

  /// SGR 7 — reverse video (swap foreground and background). `null` = unset.
  final bool? isReverse;

  /// SGR 5 — slow blink. `null` = unset (inheritable).
  final bool? isBlink;

  /// SGR 53 — overline. `null` = unset (inheritable).
  final bool? isOverline;

  /// Whether spaces inside underlined text are also underlined (default true).
  final bool underlineSpaces;

  /// Whether spaces inside struck-through text are also struck through (default true).
  final bool strikethroughSpaces;

  final EdgeInsets padding;
  final EdgeInsets margin;
  final Border border;

  /// Foreground (text) color of the border characters themselves.
  final RgbColor? borderForeground;

  /// Background color of the border characters.
  final RgbColor? borderBackground;

  /// Optional title string embedded into the top border edge.
  final String borderTitle;

  /// Horizontal alignment of [borderTitle] within the top edge.
  final Align borderTitleAlignment;

  final int? width;
  final int? height;
  final int? maxWidth;
  final int? maxHeight;
  final Align align;
  final AlignVertical alignVertical;
  final bool inline;

  /// When `true`, long lines are soft-wrapped at word boundaries to fit
  /// within [width] / [maxWidth] instead of being truncated.
  final bool wordWrap;

  final ColorProfile? profile;

  /// Optional post-processing function applied to the final rendered string
  /// (after layout, before returning). Useful for custom transforms.
  final String Function(String)? transform;

  // ── Fluent builder methods ────────────────────────────────────────────────

  Style foregroundColor256(int value) => copyWith(foreground256: value);
  Style backgroundColor256(int value) => copyWith(background256: value);
  Style foregroundColorRgb(int r, int g, int b) =>
      copyWith(foregroundRgb: RgbColor(r, g, b));
  Style backgroundColorRgb(int r, int g, int b) =>
      copyWith(backgroundRgb: RgbColor(r, g, b));
  Style withForegroundComplete(CompleteColor c) =>
      copyWith(foregroundComplete: c);
  Style withBackgroundComplete(CompleteColor c) =>
      copyWith(backgroundComplete: c);
  Style bold([bool value = true]) => copyWith(isBold: value);
  Style dim([bool value = true]) => copyWith(isDim: value);
  Style italic([bool value = true]) => copyWith(isItalic: value);
  Style underline([bool value = true]) => copyWith(isUnderline: value);
  Style strikethrough([bool value = true]) => copyWith(isStrikethrough: value);
  Style reverse([bool value = true]) => copyWith(isReverse: value);
  Style blink([bool value = true]) => copyWith(isBlink: value);
  Style overline([bool value = true]) => copyWith(isOverline: value);
  Style withUnderlineSpaces(bool value) => copyWith(underlineSpaces: value);
  Style withStrikethroughSpaces(bool value) =>
      copyWith(strikethroughSpaces: value);
  Style withPadding(EdgeInsets value) => copyWith(padding: value);
  Style withMargin(EdgeInsets value) => copyWith(margin: value);
  Style withBorder(Border value) => copyWith(border: value);

  /// Convenience: copy the current border style with per-side visibility flags.
  ///
  /// Only sides explicitly passed are changed; omitted sides keep their current
  /// values. This allows things like:
  /// ```dart
  /// style.withBorderSides(showBottom: false)
  /// ```
  Style withBorderSides({
    bool? showTop,
    bool? showRight,
    bool? showBottom,
    bool? showLeft,
  }) =>
      copyWith(
        border: border.copyWith(
          showTop: showTop,
          showRight: showRight,
          showBottom: showBottom,
          showLeft: showLeft,
        ),
      );
  Style withBorderForeground(RgbColor value) =>
      copyWith(borderForeground: value);
  Style withBorderBackground(RgbColor value) =>
      copyWith(borderBackground: value);
  Style withBorderTitle(String title, {Align alignment = Align.left}) =>
      copyWith(borderTitle: title, borderTitleAlignment: alignment);
  Style withWidth(int? value) => copyWith(width: value);
  Style withHeight(int? value) => copyWith(height: value);
  Style withMaxWidth(int? value) => copyWith(maxWidth: value);
  Style withMaxHeight(int? value) => copyWith(maxHeight: value);
  Style withAlign(Align value) => copyWith(align: value);
  Style withAlignVertical(AlignVertical value) =>
      copyWith(alignVertical: value);
  Style withInline(bool value) => copyWith(inline: value);
  Style withWordWrap(bool value) => copyWith(wordWrap: value);
  Style withProfile(ColorProfile? value) => copyWith(profile: value);
  Style withAdaptiveForeground(AdaptiveColor value) =>
      copyWith(adaptiveForeground: value);
  Style withAdaptiveBackground(AdaptiveColor value) =>
      copyWith(adaptiveBackground: value);
  Style withTransform(String Function(String)? fn) => copyWith(transform: fn);

  // Unset helpers (set nullable booleans back to null for inheritance)
  Style unsetBold() => _copyWithNullBool('isBold');
  Style unsetDim() => _copyWithNullBool('isDim');
  Style unsetItalic() => _copyWithNullBool('isItalic');
  Style unsetUnderline() => _copyWithNullBool('isUnderline');
  Style unsetStrikethrough() => _copyWithNullBool('isStrikethrough');
  Style unsetReverse() => _copyWithNullBool('isReverse');
  Style unsetBlink() => _copyWithNullBool('isBlink');
  Style unsetOverline() => _copyWithNullBool('isOverline');

  Style _copyWithNullBool(String field) {
    return Style(
      foreground256: foreground256,
      background256: background256,
      foregroundRgb: foregroundRgb,
      backgroundRgb: backgroundRgb,
      foregroundComplete: foregroundComplete,
      backgroundComplete: backgroundComplete,
      adaptiveForeground: adaptiveForeground,
      adaptiveBackground: adaptiveBackground,
      isBold: field == 'isBold' ? null : isBold,
      isDim: field == 'isDim' ? null : isDim,
      isItalic: field == 'isItalic' ? null : isItalic,
      isUnderline: field == 'isUnderline' ? null : isUnderline,
      isStrikethrough: field == 'isStrikethrough' ? null : isStrikethrough,
      isReverse: field == 'isReverse' ? null : isReverse,
      isBlink: field == 'isBlink' ? null : isBlink,
      isOverline: field == 'isOverline' ? null : isOverline,
      underlineSpaces: underlineSpaces,
      strikethroughSpaces: strikethroughSpaces,
      padding: padding,
      margin: margin,
      border: border,
      borderForeground: borderForeground,
      borderBackground: borderBackground,
      borderTitle: borderTitle,
      borderTitleAlignment: borderTitleAlignment,
      width: width,
      height: height,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      align: align,
      alignVertical: alignVertical,
      inline: inline,
      wordWrap: wordWrap,
      profile: profile,
      transform: transform,
    );
  }

  Style copyWith({
    int? foreground256,
    int? background256,
    RgbColor? foregroundRgb,
    RgbColor? backgroundRgb,
    CompleteColor? foregroundComplete,
    CompleteColor? backgroundComplete,
    AdaptiveColor? adaptiveForeground,
    AdaptiveColor? adaptiveBackground,
    bool? isBold,
    bool? isDim,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    bool? isReverse,
    bool? isBlink,
    bool? isOverline,
    bool? underlineSpaces,
    bool? strikethroughSpaces,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Border? border,
    RgbColor? borderForeground,
    RgbColor? borderBackground,
    String? borderTitle,
    Align? borderTitleAlignment,
    int? width,
    int? height,
    int? maxWidth,
    int? maxHeight,
    Align? align,
    AlignVertical? alignVertical,
    bool? inline,
    bool? wordWrap,
    ColorProfile? profile,
    String Function(String)? transform,
  }) {
    return Style(
      foreground256: foreground256 ?? this.foreground256,
      background256: background256 ?? this.background256,
      foregroundRgb: foregroundRgb ?? this.foregroundRgb,
      backgroundRgb: backgroundRgb ?? this.backgroundRgb,
      foregroundComplete: foregroundComplete ?? this.foregroundComplete,
      backgroundComplete: backgroundComplete ?? this.backgroundComplete,
      adaptiveForeground: adaptiveForeground ?? this.adaptiveForeground,
      adaptiveBackground: adaptiveBackground ?? this.adaptiveBackground,
      isBold: isBold ?? this.isBold,
      isDim: isDim ?? this.isDim,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      isReverse: isReverse ?? this.isReverse,
      isBlink: isBlink ?? this.isBlink,
      isOverline: isOverline ?? this.isOverline,
      underlineSpaces: underlineSpaces ?? this.underlineSpaces,
      strikethroughSpaces: strikethroughSpaces ?? this.strikethroughSpaces,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      border: border ?? this.border,
      borderForeground: borderForeground ?? this.borderForeground,
      borderBackground: borderBackground ?? this.borderBackground,
      borderTitle: borderTitle ?? this.borderTitle,
      borderTitleAlignment: borderTitleAlignment ?? this.borderTitleAlignment,
      width: width ?? this.width,
      height: height ?? this.height,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      align: align ?? this.align,
      alignVertical: alignVertical ?? this.alignVertical,
      inline: inline ?? this.inline,
      wordWrap: wordWrap ?? this.wordWrap,
      profile: profile ?? this.profile,
      transform: transform ?? this.transform,
    );
  }

  /// Inherit unset properties from [parent].
  ///
  /// For every property that is `null` (unset) in `this`, the value from
  /// [parent] is used. Explicitly-set values (including `false`) are kept.
  Style inherit(Style parent) {
    return Style(
      foreground256: foreground256 ?? parent.foreground256,
      background256: background256 ?? parent.background256,
      foregroundRgb: foregroundRgb ?? parent.foregroundRgb,
      backgroundRgb: backgroundRgb ?? parent.backgroundRgb,
      foregroundComplete: foregroundComplete ?? parent.foregroundComplete,
      backgroundComplete: backgroundComplete ?? parent.backgroundComplete,
      adaptiveForeground: adaptiveForeground ?? parent.adaptiveForeground,
      adaptiveBackground: adaptiveBackground ?? parent.adaptiveBackground,
      isBold: isBold ?? parent.isBold,
      isDim: isDim ?? parent.isDim,
      isItalic: isItalic ?? parent.isItalic,
      isUnderline: isUnderline ?? parent.isUnderline,
      isStrikethrough: isStrikethrough ?? parent.isStrikethrough,
      isReverse: isReverse ?? parent.isReverse,
      isBlink: isBlink ?? parent.isBlink,
      isOverline: isOverline ?? parent.isOverline,
      underlineSpaces: underlineSpaces,
      strikethroughSpaces: strikethroughSpaces,
      padding: padding,
      margin: margin,
      border: border,
      borderForeground: borderForeground ?? parent.borderForeground,
      borderBackground: borderBackground ?? parent.borderBackground,
      borderTitle: borderTitle.isNotEmpty ? borderTitle : parent.borderTitle,
      borderTitleAlignment: borderTitleAlignment,
      width: width ?? parent.width,
      height: height ?? parent.height,
      maxWidth: maxWidth ?? parent.maxWidth,
      maxHeight: maxHeight ?? parent.maxHeight,
      align: align,
      alignVertical: alignVertical,
      inline: inline,
      wordWrap: wordWrap,
      profile: profile ?? parent.profile,
      transform: transform ?? parent.transform,
    );
  }

  /// Render [value] with all style attributes applied.
  String render(String value) {
    String result;
    if (inline) {
      // Inline mode: single line, no top/bottom padding or border
      final singleLine = value.replaceAll('\n', ' ');
      result = _wrapAnsi(singleLine);
    } else {
      final lines = value.split('\n');
      final wrapped = _applyWordWrap(lines);
      final padded = _applyPadding(wrapped);
      final constrained = _applyConstraints(padded);
      final withBorder = _applyBorder(constrained);
      final withMargin = _applyMargin(withBorder);
      final content = withMargin.join('\n');
      result = _wrapAnsi(content);
    }
    return transform != null ? transform!(result) : result;
  }

  // ── Internal pipeline ─────────────────────────────────────────────────────

  /// If [wordWrap] is true, expand lines that exceed the target width.
  List<String> _applyWordWrap(List<String> lines) {
    if (!wordWrap) return lines;
    final targetWidth = width ?? maxWidth;
    if (targetWidth == null) return lines;
    final innerWidth = targetWidth - padding.left - padding.right;
    if (innerWidth <= 0) return lines;
    return lines.expand((line) => _wordWrapLine(line, innerWidth)).toList();
  }

  List<String> _applyPadding(List<String> lines) {
    final maxW = lines.fold<int>(
      0,
      (m, line) {
        final w = _visibleWidth(line);
        return w > m ? w : m;
      },
    );
    final innerWidth = maxW + padding.left + padding.right;

    final out = <String>[];
    for (var i = 0; i < padding.top; i++) {
      out.add(' ' * innerWidth);
    }
    for (final line in lines) {
      final vis = _visibleWidth(line);
      final padRight = maxW - vis;
      out.add(
          '${' ' * padding.left}$line${' ' * padRight}${' ' * padding.right}');
    }
    for (var i = 0; i < padding.bottom; i++) {
      out.add(' ' * innerWidth);
    }
    return out;
  }

  List<String> _applyConstraints(List<String> lines) {
    var result = lines;

    // Width constraint
    final targetWidth = width ?? maxWidth;
    if (targetWidth != null) {
      result = result.expand((line) {
        final vis = _visibleWidth(line);
        if (vis > targetWidth) {
          // wordWrap was already applied before padding; here just truncate
          return [_truncateVisible(line, targetWidth)];
        }
        return [line];
      }).toList();
    }

    // Alignment (horizontal) applied to target width
    if (align != Align.left && result.isNotEmpty) {
      final effectiveWidth = width ??
          (result.fold<int>(
            0,
            (m, l) {
              final w = _visibleWidth(l);
              return w > m ? w : m;
            },
          ));
      result = result
          .map((line) => _alignLine(line, effectiveWidth, align))
          .toList();
    } else if (width != null) {
      // Left-align: pad to width
      result = result.map((line) {
        final vis = _visibleWidth(line);
        if (vis < width!) {
          return line + ' ' * (width! - vis);
        }
        return line;
      }).toList();
    }

    // Height constraint
    final targetHeight = height ?? maxHeight;
    if (targetHeight != null) {
      if (result.length > targetHeight) {
        result = result.sublist(0, targetHeight);
      } else if (height != null && result.length < height!) {
        final deficit = height! - result.length;
        result = _distributeVerticalPadding(result, deficit, alignVertical);
      }
    }

    return result;
  }

  static List<String> _distributeVerticalPadding(
    List<String> lines,
    int deficit,
    AlignVertical align,
  ) {
    switch (align) {
      case AlignVertical.top:
        return [...lines, ...List.filled(deficit, '')];
      case AlignVertical.bottom:
        return [...List.filled(deficit, ''), ...lines];
      case AlignVertical.middle:
        final top = deficit ~/ 2;
        final bottom = deficit - top;
        return [...List.filled(top, ''), ...lines, ...List.filled(bottom, '')];
    }
  }

  List<String> _applyBorder(List<String> lines) {
    if (!border.enabled) return lines;
    final maxW = lines.fold<int>(
      0,
      (m, line) {
        final w = _visibleWidth(line);
        return w > m ? w : m;
      },
    );
    final horizontal = border.horizontal * maxW;

    // Build top edge with optional title
    final String topEdge;
    if (borderTitle.isNotEmpty) {
      topEdge = _buildBorderTitleEdge(maxW);
    } else {
      topEdge = horizontal;
    }

    // Build ANSI open/close for border characters
    final bOpen = _borderAnsiOpen();
    final bClose = bOpen.isNotEmpty ? '\x1b[0m' : '';

    final out = <String>[];

    // Top border edge
    if (border.showTop) {
      final tl = border.showLeft ? border.topLeft : '';
      final tr = border.showRight ? border.topRight : '';
      out.add('$bOpen$tl$topEdge$tr$bClose');
    }

    // Content lines with optional side borders
    for (final line in lines) {
      final vis = _visibleWidth(line);
      final pad = maxW - vis;
      final left = border.showLeft ? '$bOpen${border.vertical}$bClose' : '';
      final right = border.showRight ? '$bOpen${border.vertical}$bClose' : '';
      out.add('$left$line${' ' * pad}$right');
    }

    // Bottom border edge
    if (border.showBottom) {
      final bl = border.showLeft ? border.bottomLeft : '';
      final br = border.showRight ? border.bottomRight : '';
      out.add('$bOpen$bl$horizontal$br$bClose');
    }

    return out;
  }

  /// Build the top border edge string with the title embedded.
  String _buildBorderTitleEdge(int innerWidth) {
    final titleLen = _visibleWidth(borderTitle);
    final availableForDashes = innerWidth - titleLen;
    if (availableForDashes <= 0) {
      // Title too long — truncate it
      return _truncateVisible(borderTitle, innerWidth);
    }
    final leftDashes = switch (borderTitleAlignment) {
      Align.left => 0,
      Align.center => availableForDashes ~/ 2,
      Align.right => availableForDashes,
    };
    final rightDashes = availableForDashes - leftDashes;
    return '${border.horizontal * leftDashes}$borderTitle${border.horizontal * rightDashes}';
  }

  /// Returns ANSI open sequence for border coloring, or empty string.
  String _borderAnsiOpen() {
    final open = StringBuffer();
    if (borderForeground != null) {
      final c = borderForeground!;
      open.write('\x1b[38;2;${c.r};${c.g};${c.b}m');
    }
    if (borderBackground != null) {
      final c = borderBackground!;
      open.write('\x1b[48;2;${c.r};${c.g};${c.b}m');
    }
    return open.toString();
  }

  List<String> _applyMargin(List<String> lines) {
    final maxW = lines.fold<int>(
      0,
      (m, line) {
        final w = _visibleWidth(line);
        return w > m ? w : m;
      },
    );
    final out = <String>[];
    for (var i = 0; i < margin.top; i++) {
      out.add('');
    }
    for (final line in lines) {
      final vis = _visibleWidth(line);
      final pad = maxW - vis;
      out.add('${' ' * margin.left}$line${' ' * pad}${' ' * margin.right}');
    }
    for (var i = 0; i < margin.bottom; i++) {
      out.add('');
    }
    return out;
  }

  String _wrapAnsi(String value) {
    final open = StringBuffer();

    if (isBold ?? false) open.write('\x1b[1m');
    if (isDim ?? false) open.write('\x1b[2m');
    if (isItalic ?? false) open.write('\x1b[3m');
    if (isUnderline ?? false) open.write('\x1b[4m');
    if (isBlink ?? false) open.write('\x1b[5m');
    if (isReverse ?? false) open.write('\x1b[7m');
    if (isStrikethrough ?? false) open.write('\x1b[9m');
    if (isOverline ?? false) open.write('\x1b[53m');

    // Resolve effective foreground/background considering CompleteColor,
    // adaptive colors, and profile.
    final effectiveFg = _resolveColor(
      explicitComplete: foregroundComplete,
      explicit256: foreground256,
      explicitRgb: foregroundRgb,
      adaptive: adaptiveForeground,
      isBackground: false,
    );
    final effectiveBg = _resolveColor(
      explicitComplete: backgroundComplete,
      explicit256: background256,
      explicitRgb: backgroundRgb,
      adaptive: adaptiveBackground,
      isBackground: true,
    );

    if (effectiveFg != null) {
      open.write(_colorCode(effectiveFg, foreground: true));
    }
    if (effectiveBg != null) {
      open.write(_colorCode(effectiveBg, foreground: false));
    }

    if (open.isEmpty) return value;

    // When underlineSpaces is false and underline is set, wrap each word
    // individually.
    if ((isUnderline ?? false) && !underlineSpaces) {
      final reset = TuiStyle.reset;
      final reOpen = open.toString();
      final result = value.replaceAll(' ', '$reset $reOpen');
      return '$reOpen$result$reset';
    }
    if ((isStrikethrough ?? false) && !strikethroughSpaces) {
      final reset = TuiStyle.reset;
      final reOpen = open.toString();
      final result = value.replaceAll(' ', '$reset $reOpen');
      return '$reOpen$result$reset';
    }

    return '$open$value${TuiStyle.reset}';
  }

  /// Resolve a color, considering [CompleteColor], adaptive colors, and profile.
  _ResolvedColor? _resolveColor({
    CompleteColor? explicitComplete,
    int? explicit256,
    RgbColor? explicitRgb,
    AdaptiveColor? adaptive,
    required bool isBackground,
  }) {
    final activeProfile = profile ?? ColorProfile.trueColor;
    if (activeProfile == ColorProfile.noColor) return null;

    // CompleteColor takes precedence: pick the value for this profile tier.
    if (explicitComplete != null) {
      switch (activeProfile) {
        case ColorProfile.noColor:
          return null;
        case ColorProfile.ansi:
          final ansi = explicitComplete.ansi;
          if (ansi != null) return _ResolvedColor.ansi16(ansi);
          // Fall through to rgb/256 downgrade
          break;
        case ColorProfile.ansi256:
          final idx = explicitComplete.ansi256;
          if (idx != null) return _ResolvedColor.ansi256(idx);
          break;
        case ColorProfile.trueColor:
          final rgb = explicitComplete.trueColor;
          if (rgb != null) return _ResolvedColor.rgb(rgb);
          break;
      }
    }

    RgbColor? rgb;
    int? idx256;

    if (adaptive != null) {
      final bgRgb = backgroundRgb ??
          (background256 != null ? _ansi256ToRgb(background256!) : null);
      final isDark = bgRgb == null || _isDarkBackground(bgRgb);
      rgb = isDark ? adaptive.dark : adaptive.light;
    } else if (explicitRgb != null) {
      rgb = explicitRgb;
    } else if (explicit256 != null) {
      idx256 = explicit256;
    }

    if (rgb == null && idx256 == null) return null;

    switch (activeProfile) {
      case ColorProfile.noColor:
        return null;
      case ColorProfile.ansi:
        final ansi16 = rgb != null
            ? _nearestAnsi16(rgb)
            : _nearestAnsi16(_ansi256ToRgb(idx256!));
        return _ResolvedColor.ansi16(ansi16);
      case ColorProfile.ansi256:
        if (idx256 != null) return _ResolvedColor.ansi256(idx256);
        return _ResolvedColor.ansi256(_nearestAnsi256(rgb!));
      case ColorProfile.trueColor:
        if (rgb != null) return _ResolvedColor.rgb(rgb);
        if (idx256 != null) return _ResolvedColor.ansi256(idx256);
        return null;
    }
  }

  String _colorCode(_ResolvedColor color, {required bool foreground}) {
    final base = foreground ? 38 : 48;
    return switch (color.type) {
      _ColorType.ansi16 => _ansi16Code(color.value, foreground: foreground),
      _ColorType.ansi256 => '\x1b[$base;5;${color.value}m',
      _ColorType.rgb => '\x1b[$base;2;${color.r};${color.g};${color.b}m',
    };
  }

  static String _ansi16Code(int index, {required bool foreground}) {
    if (index < 8) {
      return foreground ? '\x1b[${30 + index}m' : '\x1b[${40 + index}m';
    } else {
      return foreground
          ? '\x1b[${90 + index - 8}m'
          : '\x1b[${100 + index - 8}m';
    }
  }
}

// ── Word wrap helpers ──────────────────────────────────────────────────────────

/// Wrap [line] to fit within [maxWidth] visible columns.
/// Returns one or more lines.
List<String> _wordWrapLine(String line, int maxWidth) {
  if (_visibleWidth(line) <= maxWidth) return [line];
  final words = line.split(' ');
  final result = <String>[];
  final current = StringBuffer();
  var currentWidth = 0;

  for (final word in words) {
    final wordWidth = _visibleWidth(word);
    if (current.isEmpty) {
      if (wordWidth > maxWidth) {
        result.addAll(_hardWrapWord(word, maxWidth));
      } else {
        current.write(word);
        currentWidth = wordWidth;
      }
    } else {
      if (currentWidth + 1 + wordWidth <= maxWidth) {
        current.write(' $word');
        currentWidth += 1 + wordWidth;
      } else {
        result.add(current.toString());
        current.clear();
        currentWidth = 0;
        if (wordWidth > maxWidth) {
          result.addAll(_hardWrapWord(word, maxWidth));
        } else {
          current.write(word);
          currentWidth = wordWidth;
        }
      }
    }
  }
  if (current.isNotEmpty) result.add(current.toString());
  return result.isEmpty ? [''] : result;
}

/// Hard-break a single long word across multiple lines.
List<String> _hardWrapWord(String word, int maxWidth) {
  final result = <String>[];
  final chars = word.characters.toList();
  final current = StringBuffer();
  var currentWidth = 0;
  for (final char in chars) {
    final w = _visibleWidth(char);
    if (currentWidth + w > maxWidth) {
      if (current.isNotEmpty) result.add(current.toString());
      current.clear();
      currentWidth = 0;
    }
    current.write(char);
    currentWidth += w;
  }
  if (current.isNotEmpty) result.add(current.toString());
  return result;
}

// ── Color resolution helpers ──────────────────────────────────────────────────

enum _ColorType { ansi16, ansi256, rgb }

final class _ResolvedColor {
  const _ResolvedColor.ansi16(this.value)
      : type = _ColorType.ansi16,
        r = 0,
        g = 0,
        b = 0;
  const _ResolvedColor.ansi256(this.value)
      : type = _ColorType.ansi256,
        r = 0,
        g = 0,
        b = 0;
  _ResolvedColor.rgb(RgbColor c)
      : type = _ColorType.rgb,
        value = 0,
        r = c.r,
        g = c.g,
        b = c.b;

  final _ColorType type;
  final int value;
  final int r, g, b;
}

bool _isDarkBackground(RgbColor c) {
  final lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
  return lum < 128;
}

/// Map a 256-color index to approximate RGB.
RgbColor _ansi256ToRgb(int idx) {
  if (idx < 16) {
    const colors = [
      RgbColor(0, 0, 0),
      RgbColor(128, 0, 0),
      RgbColor(0, 128, 0),
      RgbColor(128, 128, 0),
      RgbColor(0, 0, 128),
      RgbColor(128, 0, 128),
      RgbColor(0, 128, 128),
      RgbColor(192, 192, 192),
      RgbColor(128, 128, 128),
      RgbColor(255, 0, 0),
      RgbColor(0, 255, 0),
      RgbColor(255, 255, 0),
      RgbColor(0, 0, 255),
      RgbColor(255, 0, 255),
      RgbColor(0, 255, 255),
      RgbColor(255, 255, 255),
    ];
    return colors[idx];
  } else if (idx < 232) {
    final i = idx - 16;
    final r = (i ~/ 36) % 6;
    final g = (i ~/ 6) % 6;
    final b = i % 6;
    int scale(int v) => v == 0 ? 0 : 55 + v * 40;
    return RgbColor(scale(r), scale(g), scale(b));
  } else {
    final v = 8 + (idx - 232) * 10;
    return RgbColor(v, v, v);
  }
}

int _nearestAnsi16(RgbColor rgb) {
  const palette = [
    RgbColor(0, 0, 0),
    RgbColor(128, 0, 0),
    RgbColor(0, 128, 0),
    RgbColor(128, 128, 0),
    RgbColor(0, 0, 128),
    RgbColor(128, 0, 128),
    RgbColor(0, 128, 128),
    RgbColor(192, 192, 192),
    RgbColor(128, 128, 128),
    RgbColor(255, 0, 0),
    RgbColor(0, 255, 0),
    RgbColor(255, 255, 0),
    RgbColor(0, 0, 255),
    RgbColor(255, 0, 255),
    RgbColor(0, 255, 255),
    RgbColor(255, 255, 255),
  ];
  var best = 0;
  var bestDist = _colorDist(rgb, palette[0]);
  for (var i = 1; i < palette.length; i++) {
    final d = _colorDist(rgb, palette[i]);
    if (d < bestDist) {
      bestDist = d;
      best = i < 8 ? i : i - 8;
    }
  }
  return best;
}

int _nearestAnsi256(RgbColor rgb) {
  var best = 0;
  var bestDist = double.infinity;
  for (var i = 0; i < 256; i++) {
    final c = _ansi256ToRgb(i);
    final d = _colorDist(rgb, c);
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}

double _colorDist(RgbColor a, RgbColor b) {
  final dr = (a.r - b.r).toDouble();
  final dg = (a.g - b.g).toDouble();
  final db = (a.b - b.b).toDouble();
  return dr * dr + dg * dg + db * db;
}

// ── Color utility functions ────────────────────────────────────────────────────

/// Lighten [c] by [amount] (0.0–1.0): blend toward white.
RgbColor lighten(RgbColor c, double amount) {
  final t = amount.clamp(0.0, 1.0);
  return RgbColor(
    (c.r + (255 - c.r) * t).round().clamp(0, 255),
    (c.g + (255 - c.g) * t).round().clamp(0, 255),
    (c.b + (255 - c.b) * t).round().clamp(0, 255),
  );
}

/// Darken [c] by [amount] (0.0–1.0): blend toward black.
RgbColor darken(RgbColor c, double amount) {
  final t = amount.clamp(0.0, 1.0);
  return RgbColor(
    (c.r * (1 - t)).round().clamp(0, 255),
    (c.g * (1 - t)).round().clamp(0, 255),
    (c.b * (1 - t)).round().clamp(0, 255),
  );
}

/// Linearly interpolate between [a] and [b] by [t] (0.0 = all a, 1.0 = all b).
RgbColor blend(RgbColor a, RgbColor b, double t) {
  final s = t.clamp(0.0, 1.0);
  return RgbColor(
    (a.r + (b.r - a.r) * s).round().clamp(0, 255),
    (a.g + (b.g - a.g) * s).round().clamp(0, 255),
    (a.b + (b.b - a.b) * s).round().clamp(0, 255),
  );
}

// ── Width helpers ─────────────────────────────────────────────────────────────

final _ansiEscapeRe = RegExp(r'\x1b(?:\[[0-9;?]*[A-Za-z]|[\]O][^\x07]*\x07?)');

/// Strip ANSI escape sequences from [s].
String stripAnsi(String s) => s.replaceAll(_ansiEscapeRe, '');

/// Visible display width of [s] after stripping ANSI escape sequences.
///
/// Handles double-width characters (CJK, full-width, some emoji ranges).
/// This is the public counterpart of the internal [_visibleWidth] helper.
int getWidth(String s) => _visibleWidth(s);

/// Number of lines in [s] (newline-delimited).
///
/// A string with no newlines returns 1; an empty string returns 1.
int getHeight(String s) => s.split('\n').length;

/// Truncate [s] to at most [maxWidth] visible terminal columns from the left,
/// preserving ANSI escape sequences.
///
/// If [s] already fits within [maxWidth] columns it is returned unchanged.
String truncate(String s, int maxWidth) => _truncateVisible(s, maxWidth);

/// Truncate [s] to at most [maxWidth] visible terminal columns from the
/// right — i.e. keep the trailing portion and drop leading characters.
///
/// ANSI codes in the leading (dropped) section are not preserved; codes in
/// the kept section are preserved.
String truncateLeft(String s, int maxWidth) {
  final stripped = stripAnsi(s);
  final totalWidth = _visibleWidth(stripped);
  if (totalWidth <= maxWidth) return s;
  final drop = totalWidth - maxWidth;
  // Walk the stripped string grapheme-by-grapheme until we've consumed [drop]
  // visible columns, then return from that character position onward in [s].
  var consumed = 0;
  for (final char in stripped.characters) {
    if (consumed >= drop) break;
    consumed += _visibleWidth(char);
  }
  // Find the corresponding position in the original string by replaying
  // from the front.  We rebuild by stripping the same leading graphemes
  // from the raw string while skipping ANSI sequences.
  var rawIdx = 0;
  var rawConsumed = 0;
  while (rawIdx < s.length && rawConsumed < drop) {
    if (s[rawIdx] == '\x1b') {
      final m = _ansiEscapeRe.matchAsPrefix(s, rawIdx);
      if (m != null) {
        rawIdx += m.group(0)!.length;
        continue;
      }
    }
    final remaining = s.substring(rawIdx);
    final char = remaining.characters.first;
    final w = _visibleWidth(char);
    if (rawConsumed + w > drop) break;
    rawConsumed += w;
    rawIdx += char.length;
  }
  return s.substring(rawIdx);
}

/// Visible display width of [s] (number of printable columns after stripping ANSI).
/// Handles double-width characters (CJK, full-width, emoji).
int _visibleWidth(String s) {
  final stripped = stripAnsi(s);
  var width = 0;
  for (final char in stripped.characters) {
    final code = char.runes.first;
    if (_isDoubleWidth(code)) {
      width += 2;
    } else {
      width += 1;
    }
  }
  return width;
}

/// Returns `true` for double-width code points (CJK, full-width, emoji).
bool _isDoubleWidth(int code) {
  return code >= 0x1100 &&
      (code <= 0x11ff || // Hangul Jamo
          (code >= 0x2e80 &&
              code <= 0x9fff) || // CJK Radicals .. CJK Unified Ideographs
          (code >= 0xac00 && code <= 0xd7af) || // Hangul Syllables
          (code >= 0xf900 && code <= 0xfaff) || // CJK Compatibility Ideographs
          (code >= 0xfe30 && code <= 0xfe4f) || // CJK Compatibility Forms
          (code >= 0xff00 && code <= 0xff60) || // Fullwidth Forms
          (code >= 0x1f300 && code <= 0x1f9ff)); // Emojis
}

/// Truncate [s] to at most [maxWidth] visible columns, preserving ANSI codes.
String _truncateVisible(String s, int maxWidth) {
  if (_visibleWidth(s) <= maxWidth) return s;
  var currentWidth = 0;
  final b = StringBuffer();
  var i = 0;
  while (i < s.length && currentWidth < maxWidth) {
    if (s[i] == '\x1b') {
      final match = _ansiEscapeRe.matchAsPrefix(s, i);
      if (match != null) {
        b.write(match.group(0));
        i += match.group(0)!.length;
        continue;
      }
    }

    final remaining = s.substring(i);
    final char = remaining.characters.first;
    final charWidth = _visibleWidth(char);

    if (currentWidth + charWidth > maxWidth) break;

    b.write(char);
    currentWidth += charWidth;
    i += char.length;
  }
  return b.toString();
}

/// Align [line] within [maxWidth] according to [align].
String _alignLine(String line, int maxWidth, Align align) {
  final vis = _visibleWidth(line);
  if (vis >= maxWidth) return line;
  final pad = maxWidth - vis;
  return switch (align) {
    Align.left => '$line${' ' * pad}',
    Align.right => '${' ' * pad}$line',
    Align.center => '${' ' * (pad ~/ 2)}$line${' ' * (pad - pad ~/ 2)}',
  };
}

// ── Join / Place functions ────────────────────────────────────────────────────

/// Join styled blocks side-by-side (horizontal composition).
///
/// [alignment] controls vertical alignment within the composed block.
/// Shorter blocks are padded with blank lines to match the tallest block.
///
/// ```dart
/// joinHorizontal(AlignVertical.top, [leftPane, rightPane])
/// ```
String joinHorizontal(AlignVertical alignment, List<String> blocks) {
  if (blocks.isEmpty) return '';
  if (blocks.length == 1) return blocks.first;

  final split = blocks.map((b) => b.split('\n')).toList();
  final maxLines = split.fold<int>(0, (m, l) => l.length > m ? l.length : m);
  final widths = split
      .map((l) => l.fold<int>(0, (m, s) {
            final w = _visibleWidth(s);
            return w > m ? w : m;
          }))
      .toList();

  final frac = alignment.fraction;

  // Pad each block to maxLines
  final padded = List.generate(split.length, (bi) {
    final lines = split[bi];
    final deficit = maxLines - lines.length;
    if (deficit == 0) return lines;
    final top = (deficit * frac).round();
    final bottom = deficit - top;
    final w = widths[bi];
    return [
      ...List.generate(top, (_) => ' ' * w),
      ...lines,
      ...List.generate(bottom, (_) => ' ' * w),
    ];
  });

  // Zip line-by-line: pad each block's line to its column width
  final result = List.generate(maxLines, (row) {
    return List.generate(split.length, (bi) {
      final line = padded[bi][row];
      final vis = _visibleWidth(line);
      final pad = widths[bi] - vis;
      return pad > 0 ? '$line${' ' * pad}' : line;
    }).join('');
  });

  return result.join('\n');
}

/// Join blocks vertically (stacked), padding narrower blocks to widest width.
///
/// [alignment] controls horizontal alignment of narrower blocks.
///
/// ```dart
/// joinVertical(Align.left, [topBlock, bottomBlock])
/// ```
String joinVertical(Align alignment, List<String> blocks) {
  if (blocks.isEmpty) return '';
  if (blocks.length == 1) return blocks.first;

  final allLines = blocks.expand((b) => b.split('\n')).toList();

  if (alignment == Align.left) {
    return allLines.join('\n');
  }

  final maxW = allLines.fold<int>(0, (m, l) {
    final w = _visibleWidth(l);
    return w > m ? w : m;
  });

  final align = alignment == Align.right ? Align.right : Align.center;
  return allLines.map((l) => _alignLine(l, maxW, align)).join('\n');
}

/// Place [content] within a box of [width] x [height].
///
/// [hAlign] and [vAlign] control placement within the box.
String place(
  int width,
  int height,
  Align hAlign,
  AlignVertical vAlign,
  String content,
) {
  return placeVertical(height, vAlign, placeHorizontal(width, hAlign, content));
}

/// Center [content] horizontally within [width] columns.
String placeHorizontal(int width, Align align, String content) {
  final lines = content.split('\n');
  final aligned = lines.map((line) {
    final vis = _visibleWidth(line);
    if (vis >= width) return line;
    final pad = width - vis;
    final left = (pad * align.fraction).round();
    final right = pad - left;
    return '${' ' * left}$line${' ' * right}';
  });
  return aligned.join('\n');
}

/// Place [content] vertically within [height] rows.
String placeVertical(int height, AlignVertical align, String content) {
  final lines = content.split('\n');
  if (lines.length >= height) return content;
  final deficit = height - lines.length;
  final top = (deficit * align.fraction).round();
  final bottom = deficit - top;
  return [
    ...List.filled(top, ''),
    ...lines,
    ...List.filled(bottom, ''),
  ].join('\n');
}

// ── Supporting types ──────────────────────────────────────────────────────────

final class EdgeInsets {
  const EdgeInsets({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  const EdgeInsets.all(int value)
      : top = value,
        right = value,
        bottom = value,
        left = value;

  const EdgeInsets.symmetric({int vertical = 0, int horizontal = 0})
      : top = vertical,
        right = horizontal,
        bottom = vertical,
        left = horizontal;

  const EdgeInsets.only({
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  });

  final int top;
  final int right;
  final int bottom;
  final int left;
}

final class Border {
  const Border({
    required this.enabled,
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.horizontal,
    required this.vertical,
    this.showTop = true,
    this.showRight = true,
    this.showBottom = true,
    this.showLeft = true,
  });

  static const none = Border(
    enabled: false,
    topLeft: '',
    topRight: '',
    bottomLeft: '',
    bottomRight: '',
    horizontal: '',
    vertical: '',
  );

  static const rounded = Border(
    enabled: true,
    topLeft: '╭',
    topRight: '╮',
    bottomLeft: '╰',
    bottomRight: '╯',
    horizontal: '─',
    vertical: '│',
  );

  static const box = Border(
    enabled: true,
    topLeft: '┌',
    topRight: '┐',
    bottomLeft: '└',
    bottomRight: '┘',
    horizontal: '─',
    vertical: '│',
  );

  static const thick = Border(
    enabled: true,
    topLeft: '┏',
    topRight: '┓',
    bottomLeft: '┗',
    bottomRight: '┛',
    horizontal: '━',
    vertical: '┃',
  );

  // ignore: constant_identifier_names
  static const double = Border(
    enabled: true,
    topLeft: '╔',
    topRight: '╗',
    bottomLeft: '╚',
    bottomRight: '╝',
    horizontal: '═',
    vertical: '║',
  );

  static const hidden = Border(
    enabled: true,
    topLeft: ' ',
    topRight: ' ',
    bottomLeft: ' ',
    bottomRight: ' ',
    horizontal: ' ',
    vertical: ' ',
  );

  /// ASCII border using `+`, `-`, and `|` characters.
  static const normal = Border(
    enabled: true,
    topLeft: '+',
    topRight: '+',
    bottomLeft: '+',
    bottomRight: '+',
    horizontal: '-',
    vertical: '|',
  );

  final bool enabled;
  final String topLeft;
  final String topRight;
  final String bottomLeft;
  final String bottomRight;
  final String horizontal;
  final String vertical;

  /// Whether to render the top border edge.
  final bool showTop;

  /// Whether to render the right border edge.
  final bool showRight;

  /// Whether to render the bottom border edge.
  final bool showBottom;

  /// Whether to render the left border edge.
  final bool showLeft;

  /// Return a copy of this border with selected sides toggled.
  Border copyWith({
    bool? showTop,
    bool? showRight,
    bool? showBottom,
    bool? showLeft,
  }) =>
      Border(
        enabled: enabled,
        topLeft: topLeft,
        topRight: topRight,
        bottomLeft: bottomLeft,
        bottomRight: bottomRight,
        horizontal: horizontal,
        vertical: vertical,
        showTop: showTop ?? this.showTop,
        showRight: showRight ?? this.showRight,
        showBottom: showBottom ?? this.showBottom,
        showLeft: showLeft ?? this.showLeft,
      );

  /// A border with only the top edge visible.
  Border get topOnly =>
      copyWith(showTop: true, showRight: false, showBottom: false, showLeft: false);

  /// A border with only the bottom edge visible.
  Border get bottomOnly =>
      copyWith(showTop: false, showRight: false, showBottom: true, showLeft: false);

  /// A border with only left and right edges visible.
  Border get sidesOnly =>
      copyWith(showTop: false, showRight: true, showBottom: false, showLeft: true);
}

final class RgbColor {
  const RgbColor(this.r, this.g, this.b);
  final int r;
  final int g;
  final int b;

  @override
  String toString() => 'RgbColor($r, $g, $b)';

  @override
  bool operator ==(Object other) =>
      other is RgbColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);
}

/// A color that explicitly specifies values for each terminal color-profile
/// tier. When used in a [Style], the value matching the active [ColorProfile]
/// is selected, falling back to lower tiers if the exact tier is not set.
final class CompleteColor {
  const CompleteColor({
    this.trueColor,
    this.ansi256,
    this.ansi,
  });

  /// True-color (24-bit RGB) value.
  final RgbColor? trueColor;

  /// ANSI 256-color index (0–255).
  final int? ansi256;

  /// ANSI 16-color index (0–15).
  final int? ansi;
}

/// Adaptive color that selects between [light] and [dark] variants based on
/// the terminal background luminance.
final class AdaptiveColor {
  const AdaptiveColor({required this.light, required this.dark});
  final RgbColor light;
  final RgbColor dark;
}

/// Minimal compatibility ANSI helpers.
abstract final class TuiStyle {
  static const reset = '\x1b[0m';
  static const bold = '\x1b[1m';
  static const dim = '\x1b[2m';

  static String fg256(int n) => '\x1b[38;5;${n}m';
  static String bg256(int n) => '\x1b[48;5;${n}m';
  static String fgRgb(int r, int g, int b) => '\x1b[38;2;$r;$g;${b}m';
  static String bgRgb(int r, int g, int b) => '\x1b[48;2;$r;$g;${b}m';

  static String wrap(String s, {String open = '', String close = reset}) =>
      '$open$s$close';
}

// ── Gradient text functions ────────────────────────────────────────────────────

/// Render [text] with a per-character horizontal foreground color gradient
/// smoothly blended across [colors].
///
/// [colors] must have at least 2 entries. The gradient is computed in true-color
/// RGB space; each grapheme cluster receives its own `\x1b[38;2;r;g;bm` code.
/// Use [gradientBackground] for background gradients.
String gradientText(String text, List<RgbColor> colors) {
  assert(colors.length >= 2, 'gradientText requires at least 2 colors');
  final chars = text.characters.toList();
  if (chars.isEmpty) return '';
  final b = StringBuffer();
  final n = colors.length - 1;
  for (var i = 0; i < chars.length; i++) {
    final t = chars.length == 1 ? 0.0 : i / (chars.length - 1);
    final seg = (t * n).floor().clamp(0, n - 1);
    final localT = (t * n) - seg;
    final c = blend(colors[seg], colors[seg + 1], localT);
    b.write('\x1b[38;2;${c.r};${c.g};${c.b}m${chars[i]}');
  }
  b.write('\x1b[0m');
  return b.toString();
}

/// Render [text] with a per-character horizontal background color gradient.
///
/// Like [gradientText] but applies colors to the background (`\x1b[48;2;...`).
/// An optional [foreground] [Style] is applied to the whole string.
String gradientBackground(
  String text,
  List<RgbColor> colors, {
  Style? foreground,
}) {
  assert(colors.length >= 2, 'gradientBackground requires at least 2 colors');
  final chars = text.characters.toList();
  if (chars.isEmpty) return '';
  final fgCode = foreground != null ? _extractFgCode(foreground) : '';
  final b = StringBuffer();
  final n = colors.length - 1;
  for (var i = 0; i < chars.length; i++) {
    final t = chars.length == 1 ? 0.0 : i / (chars.length - 1);
    final seg = (t * n).floor().clamp(0, n - 1);
    final localT = (t * n) - seg;
    final c = blend(colors[seg], colors[seg + 1], localT);
    b.write('\x1b[48;2;${c.r};${c.g};${c.b}m$fgCode${chars[i]}');
  }
  b.write('\x1b[0m');
  return b.toString();
}

/// Extract the foreground ANSI code string from a [Style] (no layout applied).
String _extractFgCode(Style s) {
  if (s.foregroundRgb != null) {
    final c = s.foregroundRgb!;
    return '\x1b[38;2;${c.r};${c.g};${c.b}m';
  }
  if (s.foreground256 != null) return '\x1b[38;5;${s.foreground256}m';
  if (s.isBold ?? false) return '\x1b[1m';
  return '';
}

// ── Background detection helper ────────────────────────────────────────────────

/// Returns `true` if the packed RGB integer [rgb] (as returned by
/// [BackgroundColorMsg.rgb]) represents a dark background.
///
/// Uses the ITU-R BT.601 luminance formula; values below 128 are considered dark.
bool isDarkRgb(int rgb) {
  final r = (rgb >> 16) & 0xff;
  final g = (rgb >> 8) & 0xff;
  final b = rgb & 0xff;
  final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  return lum < 128;
}
