Output example/tapes/output/color_profile.gif

# The same app, run three times. The Program detects the colour profile from
# the environment, and every Style follows it: true colour, then 256 colours,
# then NO_COLOR (bold and underline stay).

Set FontSize 14
Set Width 820
Set Height 760
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Type "COLORTERM=truecolor dart run tool/bin/color_profile.dill"
Enter
Wait+Screen@20s /q: quit/
Sleep 1.5s
Type "q"
Sleep 500ms
Type "env -u COLORTERM TERM=xterm-256color dart run tool/bin/color_profile.dill"
Enter
Sleep 2.5s
Type "q"
Sleep 500ms
Type "NO_COLOR=1 dart run tool/bin/color_profile.dill"
Enter
Sleep 2.5s
Type "q"
Sleep 2s
