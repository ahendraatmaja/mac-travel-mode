# dmgbuild settings for the Travel Mode disk image. Used by make-dmg.sh:
#   dmgbuild -s dmg-settings.py -D app=... -D background=... -D volicon=... "Travel Mode" out.dmg
import os.path

app = defines["app"]
appname = os.path.basename(app)

format = "ULFO"            # lzfse-compressed, read-only (macOS 10.11+)
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = defines.get("volicon")
background = defines.get("background")

window_rect = ((200, 120), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
arrange_by = None
icon_size = 128
text_size = 13
icon_locations = {
    appname: (160, 190),
    "Applications": (480, 190),
}
