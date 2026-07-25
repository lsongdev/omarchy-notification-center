# Omarchy Notification Center

A notification daemon and bar widget for the Omarchy shell. It provides:

- notification popups with icons, images, urgency styling, and default actions;
- persistent Pending and Recently Seen history;
- a Do Not Disturb mode that retains suppressed notifications for later review;
- per-notification dismissal, Mark All as Seen, and Clear Recent controls;
- notification history and DND IPC commands compatible with Omarchy's
  `notifications` target.

The plugin stores history and DND state in
`~/.local/state/omarchy/notifications.json`. Disposable notification images
are cached under `~/.cache/omarchy/notification-images/`.

## Compatibility

This repository is the standalone replacement for Omarchy's bundled
`omarchy.notifications` plugin. It requires an Omarchy shell version that no
longer loads the bundled notification service automatically. Do not enable
both implementations at once: only one process can own the desktop
notification service.

## Install

Once the bundled implementation has been removed or made optional:

```bash
omarchy plugin add https://github.com/omacom-io/omarchy-notification-center-plugin.git --enable
```

To place its widget explicitly:

```bash
omarchy bar plugin add omacom.notification-center --section right
```

## Development

Validate the manifest and entry points:

```bash
omarchy plugin validate .
```

For local development, clone or symlink this repository into
`~/.config/omarchy/plugins/omacom.notification-center`, rescan plugins, and
enable it only after the bundled notification service is inactive:

```bash
omarchy plugin rescan
omarchy plugin enable omacom.notification-center --section right
```

## License

MIT
