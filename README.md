# Cyber Forensics Club Linux Distribution
This is a custom-spun version of Kali Linux containing tools and configurations
useful for cyber security.

![Distribution Slideshow](https://github.com/Purdue-Cyber-Forensics-Club/linux-distro/raw/master/KaliSlideshow.gif)

## Feature Overview
 - Uses ZSH instead of Bash by default
 - Includes a more friendly Vim with plugins (See [Neovim Studio](https://github.com/Maxattax97/Neovim-Studio), the Vim Studio Lite edition)
 - Much improved UX and aesthetics
 - Tuned kernel for performance
 - Laptop battery optimization
 - Virtual machine drivers and interfaces, out of the box
 - Nvidia drivers with blacklisted Nouveau
 - Disabled GRUB beep (by default)
 - Included several extra packages such as Tor browser, or qBittorrent

## Cloning
```
git clone https://github.com/Purdue-Cyber-Forensics-Club/linux-distro
cd linux-distro/
```

## Building
Currently, only Gnome 3.x is stable. In the future, lightweight alternatives
(like LXQt) will be available.

To build with Gnome 3.x:
```
./build.sh --verbose
```

To build with variants:
```
./build.sh --variant kde --verbose
```

Variants include `kde`, `xfce`, `mate`, `lxde`, `i3wm`, `e17`. The `light`
variant is not expected to function properly.

## Overview
To add packages, see the list in `kali-config/variant-gnome/package-lists/kali.list.chroot`
and add or remove your own entries.

To add files at build time (after package installation), map them out to the
root directory in `kali-config/common/includes.chroot/`.

To execute scripts during build time to make dynamic changes, include them under
`kali-config/common/hooks/live/`, with the extensions `.chroot` (`.binary` and
`.installer` work too).
