import 'dart:io';

import 'msg.dart';

/// Detects the [ColorProfile] of the terminal from environment variables.
///
/// [environment] defaults to [Platform.environment] and [isTerminal] to
/// `stdout.hasTerminal`. Pass both to get a pure, repeatable result.
///
/// The rules, first match wins:
///
/// 1. `FORCE_COLOR` set to a non-zero value forces colour, even when output
///    is not a terminal: `2` gives at least [ColorProfile.ansi256], `3`
///    gives [ColorProfile.trueColor], and other values give at least
///    [ColorProfile.ansi]. The terminal rules below can raise it further.
/// 2. `NO_COLOR` set to any non-empty value gives [ColorProfile.noColor]
///    (https://no-color.org).
/// 3. `CLICOLOR_FORCE` forces colour like `FORCE_COLOR`.
/// 4. Output that is not a terminal, or `TERM=dumb`, gives
///    [ColorProfile.noColor].
/// 5. `COLORTERM=truecolor` or `24bit`, and known true-colour terminals
///    (kitty, Ghostty, WezTerm, Alacritty, foot, iTerm2, VS Code, Windows
///    Terminal), give [ColorProfile.trueColor].
/// 6. A `TERM` ending in `256color`, tmux, GNU screen and Apple Terminal give
///    [ColorProfile.ansi256].
/// 7. Anything else gives [ColorProfile.ansi].
///
/// Mirrors the env rules of charmbracelet/colorprofile `env.go`
/// (https://github.com/charmbracelet/colorprofile/blob/main/env.go), with
/// three differences: it adds `FORCE_COLOR` and `TERM_PROGRAM`, it trusts
/// `COLORTERM` inside tmux instead of running `tmux info`, and an unset
/// `TERM` is not treated as dumb (Windows terminals do not set it).
ColorProfile detectColorProfile({
  Map<String, String>? environment,
  bool? isTerminal,
}) {
  final env = environment ?? Platform.environment;
  final forced = _forcedProfile(env['FORCE_COLOR']);
  if (forced != null) return _max(forced, _terminalProfile(env));
  if (_isSet(env['NO_COLOR'])) return ColorProfile.noColor;
  final cliForced = _forcedProfile(env['CLICOLOR_FORCE']);
  if (cliForced != null) return _max(cliForced, _terminalProfile(env));
  if (isPlainOutput(env, isTerminal ?? stdout.hasTerminal)) {
    return ColorProfile.noColor;
  }
  return _terminalProfile(env);
}

/// Whether output cannot take escape codes: it is not a terminal, or
/// `TERM=dumb`. Colour detection and plain mode share this rule.
bool isPlainOutput(Map<String, String> environment, bool isTerminal) =>
    !isTerminal || environment['TERM'] == 'dumb';

/// The [ColorProfile] styles use outside a Program: true colour, unless
/// `NO_COLOR` asks for none.
ColorProfile environmentDefaultProfile([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  return _isSet(env['NO_COLOR']) && _forcedProfile(env['FORCE_COLOR']) == null
      ? ColorProfile.noColor
      : ColorProfile.trueColor;
}

/// Whether the background is dark per `COLORFGBG`; dark when unknown.
bool environmentHasDarkBackground([Map<String, String>? environment]) =>
    darkBackgroundFromColorFgBg(
      (environment ?? Platform.environment)['COLORFGBG'],
    ) ??
    true;

/// Whether `COLORFGBG` (for example `15;0`, or rxvt's `15;default;0`) names a
/// dark background, or null when it is unset or unreadable.
///
/// Indexes 0-6 and 8 are dark, as in Vim's `background` detection.
bool? darkBackgroundFromColorFgBg(String? value) {
  if (value == null || value.isEmpty) return null;
  final bg = int.tryParse(value.split(';').last.trim());
  if (bg == null || bg < 0 || bg > 15) return null;
  return bg <= 6 || bg == 8;
}

const _trueColorTerms = [
  'alacritty',
  'contour',
  'foot',
  'ghostty',
  'kitty',
  'wezterm',
];

const _trueColorPrograms = {'iTerm.app', 'WezTerm', 'ghostty', 'vscode'};

/// The profile the terminal type supports, ignoring NO_COLOR and isatty.
ColorProfile _terminalProfile(Map<String, String> env) {
  final term = (env['TERM'] ?? '').toLowerCase();
  final program = env['TERM_PROGRAM'] ?? '';
  final colorTerm = (env['COLORTERM'] ?? '').toLowerCase();
  if (colorTerm == 'truecolor' ||
      colorTerm == '24bit' ||
      term.endsWith('direct') ||
      _trueColorTerms.any(term.contains) ||
      _trueColorPrograms.contains(program) ||
      _isSet(env['WT_SESSION'])) {
    return ColorProfile.trueColor;
  }
  if (term.endsWith('256color') ||
      term.startsWith('tmux') ||
      term.startsWith('screen') ||
      program == 'Apple_Terminal') {
    return ColorProfile.ansi256;
  }
  return ColorProfile.ansi;
}

/// `FORCE_COLOR`-style levels: unset, empty, `0` and `false` do not force.
ColorProfile? _forcedProfile(String? value) {
  final v = value?.trim().toLowerCase() ?? '';
  return switch (v) {
    '' || '0' || 'false' => null,
    '2' => ColorProfile.ansi256,
    '3' => ColorProfile.trueColor,
    _ => ColorProfile.ansi,
  };
}

bool _isSet(String? value) => value != null && value.isNotEmpty;

ColorProfile _max(ColorProfile a, ColorProfile b) => a.index >= b.index ? a : b;
