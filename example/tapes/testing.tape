Output example/tapes/output/testing.gif

# The test harness clip: change the countdown's text, watch the golden test
# fail with a short diff, accept the new screen, and watch it pass. Restores
# example/simple.dart and its golden at the end.

Set FontSize 14
Set Width 1000
Set Height 640
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Type "sed -i.bak 's/Press q to quit/Press q to stop/' example/simple.dart"
Enter
Sleep 600ms

Type "dart test example/test"
Enter
Sleep 9s

Type "DART_TUI_UPDATE_GOLDENS=1 dart test example/test"
Enter
Sleep 7s

Type "clear; dart test example/test"
Enter
Sleep 7s

Hide
Type "mv example/simple.dart.bak example/simple.dart && git checkout -- example/test/goldens && clear"
Enter
Sleep 500ms
Show
