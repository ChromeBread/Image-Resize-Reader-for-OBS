# Image Resize Reader for OBS

An OBS Studio (Windows) Lua script that fits images and videos to the canvas the moment they are added, so a huge picture never lands half off-screen.

- Size: 1–100 % of the canvas, a pixel size, or original size. Fit to width, height, or both (stay inside)
- Optional enlarging of small images to the chosen size
- Position on load: any of nine anchors
- Dock with nine-point buttons: moves the selected item (or the last one placed) to the edge of the canvas, flush, without going off-screen. Rotated, cropped and bounded items work too
- Each button is also a hotkey (Settings → Hotkeys)
- UI in English / 日本語 / 한국어 / Bahasa Indonesia / Français / 繁體中文 (other OBS languages → English)

Items already in a scene, and sources added again from another scene, are left alone.

## Supported files

| Files | How to add |
|---|---|
| `.bmp .tga .png .jpg .jpeg .jxr .gif .psd .webp` | Drag & drop, or Sources → + |
| `.mp4 .m4v .mov .mkv .webm .avi .flv .ts .m2ts .mts .mpg .mpeg .wmv` | Drag & drop, or Sources → + |

## Install
1. Keep `obs_image_resize_reader.lua` and `obs_image_resize_reader_dock.html` in the same folder.
2. OBS → **Tools → Scripts → +** → select `obs_image_resize_reader.lua`.
3. Press **Show Dock URL**, copy the **Dock URL**, then **Docks → Custom Browser Docks…** → paste it.
4. Enable **Tools → WebSocket Server Settings** and enter the port / password in the dock (⚙).

## Uninstall
Remove the script from **Tools → Scripts** (select it, press **−**), close OBS, then run `Safe_Uninstaller.bat`. It shows what each file is, lets you choose what to remove, backs up your settings, explains moving to another PC, and sends everything to the Recycle Bin.

Requires OBS 28+ (built-in obs-websocket v5) on Windows.

Author: ChromeBread feat. BlackDream ・ License: GPL-2.0

This is an unofficial third-party script. It is not affiliated with or endorsed by the OBS Project.
