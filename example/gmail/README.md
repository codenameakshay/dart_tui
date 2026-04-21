# gmail — read-only Gmail TUI

A two-pane, read-only Gmail client built on `dart_tui`. Messages on the left,
selected message body on the right, Gmail search on `/`, pagination on `[` / `]`.

![layout](./layout.png)

## Requirements

- [`gws`](https://github.com/google/gws) CLI installed and authenticated (the
  example shells out to `gws gmail +triage` and `gws gmail +read`).
- Dart 3.x.

Verify `gws` works first:

```sh
gws gmail +triage --max 1 --format json
```

If that prints JSON with a `messages` array, you're good.

## Run

```sh
dart run example/gmail/main.dart
```

## Keys

| Key | Action |
| --- | --- |
| `j` / `k` or `↓` / `↑` | Move selection in the list |
| `/` | Focus search; type a Gmail query (`from:alice is:unread newer_than:7d`) |
| `enter` (in search) | Submit query |
| `esc` (in search) | Cancel search, restore list |
| `]` / `[` | Next / previous page (50 per page) |
| `tab` | Toggle focus between list and message pane |
| `g` / `G` (message focused) | Scroll message to top / bottom |
| `r` | Retry last failed load |
| `q` / `ctrl+c` | Quit |

## Architecture

```
example/gmail/
├── main.dart                  # entry point
├── gws/runner.dart            # Process.run('gws', …) wrapper
├── gmail/
│   ├── models.dart            # MessageSummary, Message, EmailAddress
│   ├── source.dart            # GmailSource interface
│   └── gws_source.dart        # shells to `gws gmail +triage` / `+read`
└── app/
    ├── model.dart             # AppModel (Elm-style update/view)
    ├── messages.dart          # MessagesLoaded / MessageBodyLoaded / LoadFailed
    └── views/
        ├── message_list.dart  # left pane renderer
        ├── message_view.dart  # right pane renderer (headers + ViewportModel body)
        └── status_bar.dart    # bottom bar + inline search input
```

Bodies are cached by message id, so revisits are instant. Pagination re-fetches
`+triage --max (pageIndex+1)*pageSize` and slices — simple and correct for a
demo, no page-token bookkeeping needed.

## Limitations

Read-only. No compose, reply, label management, or attachments. Bodies are
rendered as plain text (HTML is converted by `gws +read`).
