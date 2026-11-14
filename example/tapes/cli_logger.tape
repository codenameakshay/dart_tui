Output example/tapes/output/cli_logger.gif

# The mason_logger-shaped Logger: a "create project" flow, first in the
# terminal UI, then piped through `cat`, where the same calls ask plain
# numbered questions and the progress writes one start and one end line.

Set FontSize 14
Set Width 760
Set Height 620
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Type "dart run tool/bin/cli_logger.dill"
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
Enter
Sleep 3s

Type "dart run tool/bin/cli_logger.dill | cat"
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
Type "1,2,3"
Sleep 400ms
Enter
Sleep 600ms
Enter
Sleep 3s
