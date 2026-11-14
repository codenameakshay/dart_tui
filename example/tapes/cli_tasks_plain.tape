Output example/tapes/output/cli_tasks_plain.gif

# The same release flow piped through `cat`: no redraws and no escape codes,
# one line per finished task, and each logged line prefixed with its task.

Set FontSize 14
Set Width 760
Set Height 620
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Type "dart run tool/bin/cli_tasks.dill | cat"
Enter
Wait+Screen@20s /tasks/
Sleep 3s
