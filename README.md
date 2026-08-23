# OmaLink

Native Android phone integration for Omarchy, powered by KDE Connect.

OmaLink is currently an early technical spike. The first slice adds a themed
Omarchy bar panel that detects connected phones and can ring one. It does not
yet install KDE Connect, change firewall rules, or provide messages.

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
2. Reliable device status, battery, and connectivity
3. Ring, clipboard, and file actions
4. Mirrored notifications and notification replies
5. SMS and MMS conversations

RCS is not in scope because KDE Connect does not expose it.

## License

MIT
