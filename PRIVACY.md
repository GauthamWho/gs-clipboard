# Privacy

**G's Clipboard is fully local.** It has no account, no cloud, no analytics, and
no telemetry. The developer cannot see what you copy.

## What the app stores (only on your Mac)

Everything is kept in:

```
~/Library/Application Support/G's Clipboard/
├── index.json   metadata: the text you copied, timestamps, app names, pins
└── blobs/       images you copied, as PNG files
```

- **Text** you copy.
- **Images** you copy (screenshots, photos).
- **File paths** you copy.
- The **name of the app** you copied from (for example "Safari"), so the history
  is easier to read.
- When each item was copied.

This data never leaves your Mac. Uninstalling the app and deleting that folder
removes it permanently.

## Network access

The only network request the app makes is an **update check**:

- It sends a `GET` request to `https://api.github.com/repos/GauthamWho/gs-clipboard/releases/latest`.
- It sends **no clipboard content, no file names, no device ID, no account, and
  no analytics**.
- GitHub can see the request came from your IP address, the same as visiting any
  website. That is the only information involved.
- It happens **at most once per day**, and you can turn it off in
  **Settings → General → Automatically check for updates**.

The app does not include any other networking code.

## Permissions

- No Accessibility permission.
- No Screen Recording permission.
- No Full Disk Access.
- No login to any service.

The app reads the macOS clipboard (that is how any clipboard manager works) and
writes clipboard items back when you click them.

## Contact

Questions about privacy: [@gautamwho on Instagram](https://instagram.com/gautamwho).
