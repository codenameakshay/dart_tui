Output example/tapes/output/inline.gif

# Inline mode (#18): without the alt screen, a program draws where the cursor
# is. The shell history above it stays put, and each prompt in the chain
# starts right below the previous output.

Set FontSize 14
Set Width 760
Set Height 620
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Type "echo 'shell history: build passed'"
Enter
Sleep 300ms
Type "echo 'shell history: 42 tests green'"
Enter
Sleep 600ms
Type "dart run tool/bin/prompts_chain.dill"
Enter
Wait+Screen@20s /Enter confirm/
Sleep 500ms
Down
Sleep 400ms
Enter
Sleep 700ms
Type "y"
Sleep 700ms
Type "ship it"
Sleep 500ms
Enter
Sleep 2.5s
