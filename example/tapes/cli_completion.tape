Output example/tapes/output/cli_completion.gif

# Shell completion for the notes CLI in example/cli_app: load the zsh script,
# then Tab through the commands, a flag, an allowed value with its help, and
# note numbers from the app's own completeValue hook.

Set Shell "zsh"
Set FontSize 14
Set Width 860
Set Height 300
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Hide
Type "mkdir -p /tmp/dart_tui_completion/home && dart compile exe example/cli_app/notes.dart -o /tmp/dart_tui_completion/notes >/dev/null && export PATH=/tmp/dart_tui_completion:$PATH HOME=/tmp/dart_tui_completion/home && rm -f $HOME/.notes.json && notes add Buy milk -p high >/dev/null && notes add Call Sam >/dev/null && notes add Record the demo -p low >/dev/null && autoload -Uz compinit && compinit -u && clear"
Enter
Wait@90s
Show

Type "source <(notes completion zsh)"
Sleep 300ms
Enter
Sleep 800ms

Type "notes "
Sleep 300ms
Tab
Sleep 2.5s
Type "a"
Sleep 300ms
Tab
Sleep 800ms
Type "--pr"
Sleep 300ms
Tab
Sleep 800ms
Tab
Sleep 2.5s
Type "h"
Sleep 300ms
Tab
Sleep 1.5s

Ctrl+U
Type "clear"
Enter
Type "notes done "
Sleep 300ms
Tab
Sleep 2.5s
Type "2"
Sleep 300ms
Enter
Sleep 2s
