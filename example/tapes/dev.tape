Output example/tapes/output/dev.gif

# `dart_tui dev`: hot reload. tmux splits the screen: the counter app runs on
# the left, a shell edits its source on the right. The count survives a colour
# and layout change, and a typo shows the compile-error banner.
#
# Hidden setup: copy example/hot_reload.dart into a package in /tmp and put a
# compiled dart_tui first on PATH (see create.tape for why).

Set Shell "zsh"
Set FontSize 14
Set Width 1440
Set Height 560
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Hide
Type "rm -rf /tmp/dart_tui_dev && mkdir -p /tmp/dart_tui_dev/bin /tmp/dart_tui_dev/.bin && export DART_TUI_REPO=$PWD && cp example/hot_reload.dart /tmp/dart_tui_dev/bin/counter.dart && cd /tmp/dart_tui_dev && printf 'name: counter\nenvironment:\n  sdk: \x27>=3.5.0 <4.0.0\x27\ndependencies:\n  dart_tui:\n    path: %s\n' $DART_TUI_REPO > pubspec.yaml && dart pub get --offline >/dev/null && dart compile exe $DART_TUI_REPO/bin/dart_tui.dart -o /tmp/dart_tui_dev/.bin/dart_tui >/dev/null && export PATH=/tmp/dart_tui_dev/.bin:$PATH && clear"
Enter
Wait@180s
Type `tmux -f /dev/null new -s d13 'dart_tui dev' \; set status off \; split-window -h -l 58 'PS1="$ " exec zsh -f'`
Enter
Sleep 6s
Show

Type "grep -n 'accent =>' -A1 bin/counter.dart"
Enter
Sleep 1.5s

# Count to 5 in the app.
Ctrl+B
Left
Sleep 500ms
Type@300ms "+++++"
Sleep 1.2s

# Change the colour and the layout on disk.
Ctrl+B
Right
Sleep 400ms
Type "perl -pi -e 's/137, 180, 250/243, 139, 168/; s/boxed => false/boxed => true/' bin/counter.dart"
Sleep 400ms
Enter
Sleep 3s

# A typo: the banner shows, the app keeps running.
Type "perl -pi -e 's/boxed => true;/boxed => true/' bin/counter.dart"
Sleep 400ms
Enter
Sleep 4s

Hide
Type "tmux kill-session -t d13; cd $DART_TUI_REPO && rm -rf /tmp/dart_tui_dev"
Enter
Sleep 1s
