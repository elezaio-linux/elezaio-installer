# Elezaio Installer

A lightweight TUI installer for Elezaio Linux, built with bash and gum.

## Structure

```
elezaio-installer/
├── install.sh          # Entry point
├── config.conf         # Installer settings
├── ui/
│   ├── branding.sh     # Colors & branding
│   └── screens.sh      # All UI screens
└── core/
    ├── disk.sh         # Partitioning & file copy
    └── system.sh       # Bootloader, users & config
```

## Usage

```bash
sudo bash install.sh
```

## Screens

- Welcome
- Language selection
- Keyboard layout
- Disk selection
- Username & password
- Installation summary
- Progress
- Done & reboot

- `squashfs-tools`

## License

MIT — Elezaio Linux Project
