Output example/tapes/output/sync_prompts.gif

# The four synchronous prompts in one flow, first in the terminal UI, then
# piped through `cat`, where the same calls ask plain numbered questions.

Set FontSize 14
Set Width 760
Set Height 620
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Type "dart run tool/bin/sync_prompts.dill"
Enter
Wait+Screen@20s /Project name/
Sleep 800ms
Type "demo"
Sleep 400ms
Enter
Sleep 700ms
Down
Sleep 400ms
Enter
Sleep 700ms
Down
Down
Sleep 300ms
Space
Sleep 500ms
Enter
Sleep 700ms
Type "hunter2"
Sleep 400ms
Enter
Sleep 700ms
Enter
Sleep 3s

Type "dart run tool/bin/sync_prompts.dill | cat"
Sleep 300ms
Enter
Sleep 1.2s
Type "demo"
Sleep 400ms
Enter
Sleep 600ms
Type "2"
Sleep 400ms
Enter
Sleep 600ms
Type "1,3"
Sleep 400ms
Enter
Sleep 600ms
Type "hunter2"
Sleep 400ms
Enter
Sleep 600ms
Type "y"
Sleep 400ms
Enter
Sleep 3s
