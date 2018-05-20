HOW TO BUILD MIKUTTER FLATPAK
=============================
PREREQUISITE
------------
flatpak-builder

[Quick setup guide](https://flatpak.org/setup/)

USAGE
-----
```bash
flatpak install flathub org.gnome.Platform//3.26 org.gnome.Sdk//3.26
flatpak-builder --run build net.hachune.mikutter.json
# test
flatpak-builder --run build net.hachune.mikutter.json mikutter
```
