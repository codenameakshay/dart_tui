Output example/tapes/output/create.gif

# `dart_tui create`: install the command from this checkout, make the app
# starter with the wizard, then run it. The last hidden line removes the
# global activation again.
#
# A path activation re-resolves its dependencies on every run and prints
# that; one from pub.dev does not. So the hidden step after the activation
# puts a compiled dart_tui first on PATH, which also shows the templates work
# from `dart compile exe`.

Set Shell "zsh"
Set FontSize 14
Set Width 860
Set Height 620
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Hide
Type "rm -rf /tmp/dart_tui_create && mkdir -p /tmp/dart_tui_create/bin && export PATH=$HOME/.pub-cache/bin:$PATH && export DART_TUI_REPO=$PWD && clear"
Enter
Wait@20s
Show

Type "dart pub global activate --source path ."
Sleep 300ms
Enter
Wait+Screen@90s /Activated dart_tui/
Sleep 1.5s

Hide
Type "cd /tmp/dart_tui_create && dart compile exe $DART_TUI_REPO/bin/dart_tui.dart -o bin/dart_tui >/dev/null && export PATH=$PWD/bin:$PATH && clear"
Enter
Wait@120s
Show

Type "dart_tui create"
Sleep 300ms
Enter
Wait+Screen@90s /Project name/
Sleep 800ms
Type "todo"
Sleep 500ms
Enter
Sleep 900ms
Up
Sleep 400ms
Down
Sleep 500ms
Enter
Sleep 900ms
Enter
Wait+Screen@120s /dart test/
Sleep 2.5s

Type "cd todo && dart run"
Sleep 300ms
Enter
Wait+Screen@90s /Checklist/
Sleep 1.2s
Enter
Sleep 600ms
Down
Sleep 400ms
Down
Sleep 400ms
Space
Sleep 1.5s
Type "q"
Sleep 1.5s

Hide
Type "cd $DART_TUI_REPO && dart pub global deactivate dart_tui >/dev/null"
Enter
Wait@20s
Sleep 5s
