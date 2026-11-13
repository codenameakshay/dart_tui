Output example/tapes/output/plain_mode.gif

# Plain mode, the "agent-safe" clip: the same form twice. First in the
# terminal UI, then piped through `cat`. With stdout not a terminal the form
# asks plain line questions and writes no escape codes.

Set FontSize 14
Set Width 760
Set Height 620
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Type "dart run tool/bin/form.dill"
Enter
Sleep 1.2s
Type "billing-api"
Sleep 400ms
Tab
Sleep 300ms
Down
Sleep 300ms
Tab
Sleep 300ms
Tab
Sleep 500ms
Space
Sleep 200ms
Down
Down
Space
Sleep 400ms
Tab
Sleep 300ms
Tab
Sleep 1.2s

Type "dart run tool/bin/form.dill | cat"
Sleep 300ms
Enter
Sleep 1.2s
Type "billing-api"
Sleep 400ms
Enter
Sleep 500ms
Type "2"
Sleep 400ms
Enter
Sleep 500ms
Enter
Sleep 500ms
Type "1,3"
Sleep 400ms
Enter
Sleep 2.5s
