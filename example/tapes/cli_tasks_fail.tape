Output example/tapes/output/cli_tasks_fail.gif

# With --fail one test fails: no new tasks start, the failed task stays
# expanded with its output, and the summary counts the failure.

Set FontSize 14
Set Width 760
Set Height 420
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Type "dart run tool/bin/cli_tasks.dill --fail"
Enter
Wait+Screen@20s /failed/
Sleep 3s
