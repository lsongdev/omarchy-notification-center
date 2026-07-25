# Omarchy Notification Center

An optional bar widget for reviewing notifications handled by Omarchy's
built-in notification service.

It adds:

- a Pending tab for unseen notifications;
- a Recently tab for notifications already shown;
- per-notification dismissal;
- Mark All as Seen and Clear Recent actions;
- a Do Not Disturb toggle.

The notification daemon, toast popups, history storage, DND state, and the
standard DND indicator remain part of Omarchy itself. This plugin only provides
the bar popup for browsing that history.

## Install

```bash
omarchy plugin add https://github.com/omacom-io/omarchy-notification-center-plugin.git --enable
```

The widget can be positioned explicitly:

```bash
omarchy bar plugin move omacom.notification-center --section right
```

## Development

Validate the manifest and entry point:

```bash
omarchy plugin validate .
```

After changing plugin files:

```bash
omarchy plugin rescan
omarchy restart shell
```

## License

MIT
