# OmaLink

Native Android phone integration for Omarchy, powered by KDE Connect.

OmaLink adds a themed Omarchy bar panel with connected-phone status, battery
and signal details, clipboard and ring actions, Android notifications, contact
sync, SMS/MMS conversations, and replies. Message notification previews are
hidden by default and can be enabled in the widget settings.

## Development

Requirements for the current spike:

- Omarchy 4.0 or newer
- `jq`
- KDE Connect for live phone discovery
- Node.js for the small JavaScript model test

Run the checks:

```sh
omarchy plugin validate .
node tests/model.test.js
bash tests/cli.test.sh
```

For local shell testing, use a throwaway clone or install from a Git remote
with `omarchy plugin add`. Do not copy the repository into the live plugin
directory while editing it elsewhere because Omarchy plugins may not contain
symlinks.

## Near-term scope

1. Guided installation, pairing, permissions, and firewall diagnostics
2. File sending
3. Notification replies and event-driven refresh
4. Conversation search and new-message composition

RCS is not in scope because KDE Connect does not expose it.

## License

MIT
