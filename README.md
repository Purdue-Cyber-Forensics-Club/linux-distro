# Cyber Forensics Club Linux Distribution
This is a custom-spun version of Kali Linux containing tools and configurations
useful for cyber security.

![Distribution Slideshow](https://github.com/Purdue-Cyber-Forensics-Club/linux-distro/raw/master/KaliSlideshow.gif)

## Cloning
This repository contains embedded git repositories (submodules). Retrieve and
update them like so:
```
git clone https://github.com/Purdue-Cyber-Forensics-Club/linux-distro
cd linux-distro/
git submodule update --init --recursive
```

## Building
Currently, only Gnome 3.x is supported. In the future, lightweight alternatives
(like LXQt) will be available.
```
./build.sh --verbose
```

## Overview
To add packages, see the list in `kali-config/variant-gnome/package-lists/kali.list.chroot`
and add or remove your own entries.

To add files at build time (after package installation), map them out to the
root directory in `kali-config/common/includes.chroot/`.

To execute scripts during build time to make dynamic changes, include them under
`kali-config/common/hooks/live/`, with the extensions `.chroot` (`.binary` and
`.installer` work too).
