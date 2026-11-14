Output example/tapes/output/cli_tasks.gif

# Logger.tasks, the clip of the week: a release flow. Three checks run at
# once under "Check", the build runs two nested steps with live output under
# each, and every finished group collapses to one line.

Set FontSize 14
Set Width 760
Set Height 420
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Type "dart run tool/bin/cli_tasks.dill"
Enter
Wait+Screen@20s /tasks/
Sleep 3s
