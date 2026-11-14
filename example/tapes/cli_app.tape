Output example/tapes/output/cli_app.gif

# CliRunner, the "notes" CLI in example/cli_app: styled help with grouped
# commands, a typo answered with "did you mean", then an interactive
# `notes add` with a prompt, a choice and a progress line.

Set FontSize 14
Set Width 860
Set Height 720
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Hide
Type "dart compile kernel example/cli_app/notes.dart -o /tmp/notes.dill >/dev/null && rm -f /tmp/dart_tui_notes.json && alias notes='dart run /tmp/notes.dill -f /tmp/dart_tui_notes.json' && clear"
Enter
Wait@60s
Show

Type "notes --help"
Sleep 300ms
Enter
Wait+Screen@20s /plain JSON/
Sleep 3.5s

Type "clear"
Enter
Type "notes lsit"
Sleep 300ms
Enter
Wait+Screen@20s /Did you mean/
Sleep 3s

Type "clear"
Enter
Type "notes add"
Sleep 300ms
Enter
Wait+Screen@20s /note say/
Sleep 600ms
Type "Ship the CLI runner"
Sleep 400ms
Enter
Wait+Screen@20s /Priority/
Sleep 600ms
Down
Sleep 400ms
Enter
Wait+Screen@20s /Saved note/
Sleep 800ms
Type "notes list"
Sleep 300ms
Enter
Sleep 3s
