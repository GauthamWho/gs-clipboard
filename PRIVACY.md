# Privacy

**Gautham's Clipboard is fully local.** It has no account, no cloud, no analytics, and
no telemetry. The developer cannot see what you copy.

## What the app stores (only on your Mac)

Everything is kept in:

```
~/Library/Application Support/Gautham's Clipboard/
├── index.json   metadata: the text you copied, timestamps, app names, pins
└── blobs/       images you copied (PNG; after 2 days high-quality HEIC)
```

The folder is excluded from Time Machine and from Spotlight, so your history is not
copied into backups or shown in searches.

- **Text** you copy.
- **Images** you copy (screenshots, photos).
- **File paths** you copy.
- The **name of the app** you copied from (for example "Safari"), so the history
  is easier to read.
- When each item was copied, and how often you pasted it again (used by smart
  cleanup to keep what you reuse).

**Not stored:** copies that password managers and other apps mark as private
(`org.nspasteboard.ConcealedType` and similar).

**Cleaned up automatically** (Settings → History → Smart cleanup): unused
screenshots after 10 days, unused text after 45 days, one-time codes after 20
minutes. Pinned items are never removed.

A small **diagnostic log** is also written to `~/Library/Logs/Gautham's Clipboard.log`.
It records things like "captured text, 42 characters" and "panel opened", so a
problem can be diagnosed without seeing your actual content. It is plain text on
your Mac and you can delete it at any time.

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

- Accessibility (optional): used only to (1) press ⌘V or type an emoji in the app
  you were using, (2) read the position of your text cursor in that app's focused
  field, so the panel opens beside it, and (3) notice an **fn** shortcut (like the
  default fn V). For (3) the app looks at each key press only to check whether it is
  your shortcut; it never stores, logs or sends key presses, and every other key
  passes straight through. It does not read the text in other apps or look at other
  windows. Shortcuts without fn use the standard hot-key API and need no permission.
- No Screen Recording permission.
- No Full Disk Access.
- No login to any service.

The app reads the macOS clipboard (that is how any clipboard manager works) and
writes clipboard items back when you click them.

## Contact

Questions about privacy: [@gautamwho on Instagram](https://instagram.com/gautamwho).
