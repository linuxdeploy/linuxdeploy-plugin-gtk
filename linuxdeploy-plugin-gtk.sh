#! /bin/bash

# abort on all errors
set -e

if [ "$DEBUG" != "" ]; then
    set -x
    verbose="--verbose"
fi

script=$(readlink -f "$0")

show_usage() {
    echo "Usage: $script --appdir <path to AppDir>"
    echo
    echo "Bundles resources for applications that use Gtk 2 or 3 into an AppDir"
}

copy_tree() {
    local src=("${@:1:$#-1}")
    local dst="${*:$#}"

    for elem in "${src[@]}"; do
        cp "$elem" --archive --parents --target-directory="$dst" $verbose
    done
}

search_tool() {
    local tool="$1"
    local directory="$2"

    if command -v "$tool"; then
        return 0
    fi

    PATH_ARRAY=(
        "/usr/lib/$(uname -m)-linux-gnu/$directory/$tool"
        "/usr/lib/$directory/$tool"
        "/usr/bin/$tool"
        "/usr/bin/$tool-64"
        "/usr/bin/$tool-32"
    )

    for path in "${PATH_ARRAY[@]}"; do
        if [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done
}

APPDIR=

while [ "$1" != "" ]; do
    case "$1" in
        --plugin-api-version)
            echo "0"
            exit 0
            ;;
        --appdir)
            APPDIR="$2"
            shift
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Invalid argument: $1"
            echo
            show_usage
            exit 1
            ;;
    esac
done

if [ "$APPDIR" == "" ]; then
    show_usage
    exit 1
fi

mkdir -p "$APPDIR"

if command -v pkgconf > /dev/null; then
    PKG_CONFIG="pkgconf"
elif command -v pkg-config > /dev/null; then
    PKG_CONFIG="pkg-config"
else
    echo "$0: pkg-config/pkgconf not found in PATH, aborting"
    exit 1
fi

if ! which patchelf &>/dev/null && ! type patchelf &>/dev/null; then
    echo -e "$0: patchelf not found.\nInstall patchelf then re-run the plugin."
    exit 1
fi

if [ -z "$LINUXDEPLOY" ]; then
    echo -e "$0: LINUXDEPLOY environment variable is not set.\nDownload a suitable linuxdeploy AppImage, set the environment variable and re-run the plugin."
    exit 1
fi

echo "Installing AppRun hook"
HOOKSDIR="$APPDIR/apprun-hooks"
HOOKFILE="$HOOKSDIR/linuxdeploy-plugin-gtk.sh"
mkdir -p "$HOOKSDIR"
cat > "$HOOKFILE" <<\EOF
#! /bin/bash

gsettings get org.gnome.desktop.interface gtk-theme 2> /dev/null | grep -qi "dark" && GTK_THEME_VARIANT="dark" || GTK_THEME_VARIANT="light"
APPIMAGE_GTK_THEME="${APPIMAGE_GTK_THEME:-"Adwaita:$GTK_THEME_VARIANT"}" # Allow user to override theme (discouraged)
CACHEDIR="$(mktemp --tmpdir --directory .AppRun.XXXXXXXX)"

export APPDIR="${APPDIR:-"$(dirname "$(realpath "$0")")"}" # Workaround to run extracted AppImage
export OLDPATH="$PATH"
export PATH="$APPDIR/usr/bin:$PATH"

export GTK_DATA_PREFIX="$APPDIR"
export GTK_THEME="$APPIMAGE_GTK_THEME" # Custom themes are broken
export GDK_BACKEND=x11 # Crash with Wayland backend on Wayland
export XDG_DATA_DIRS="$APPDIR/usr/share:/usr/share:$XDG_DATA_DIRS" # g_get_system_data_dirs() from GLib
EOF

echo "Installing GLib schemas"
glib_schemasdir="$("$PKG_CONFIG" --variable=schemasdir gio-2.0)"
[ -z "$glib_schemasdir" ] && glib_schemasdir="/usr/share/glib-2.0/schemas" # Fix for Ubuntu 16.04
copy_tree "$glib_schemasdir" "$APPDIR/"
glib-compile-schemas "$APPDIR/$glib_schemasdir"
cat >> "$HOOKFILE" <<EOF
export GSETTINGS_SCHEMA_DIR="\$APPDIR/$glib_schemasdir"
EOF

echo "Installing GTK 3.0 modules"
gtk3_exec_prefix="$("$PKG_CONFIG" --variable=exec_prefix gtk+-3.0)"
gtk3_libdir="$("$PKG_CONFIG" --variable=libdir gtk+-3.0)/gtk-3.0"
gtk3_immodulesdir="$gtk3_libdir/$("$PKG_CONFIG" --variable=gtk_binary_version gtk+-3.0)/immodules"
gtk3_printbackendsdir="$gtk3_libdir/$("$PKG_CONFIG" --variable=gtk_binary_version gtk+-3.0)/printbackends"
gtk3_immodules_cache_file="$(dirname "$gtk3_immodulesdir")/immodules.cache"
gtk3_immodules_query="$(search_tool "gtk-query-immodules-3.0" "libgtk-3-0")"
copy_tree "$gtk3_libdir" "$APPDIR/"
cat >> "$HOOKFILE" <<EOF
export GTK_EXE_PREFIX="\$APPDIR/$gtk3_exec_prefix"
export GTK_PATH="\$APPDIR/$gtk3_libdir"
export GTK_IM_MODULE_DIR="\$APPDIR/$gtk3_immodulesdir"
export GTK_IM_MODULE_FILE="\$CACHEDIR/immodules.cache"
sed "s|$gtk3_libdir|\$APPDIR/$gtk3_libdir|g" "\$APPDIR/$gtk3_immodules_cache_file" > "\$GTK_IM_MODULE_FILE"
EOF
if [ -x "$gtk3_immodules_query" ]; then
    echo "Updating immodules cache in $APPDIR/$gtk3_immodules_cache_file"
    "$gtk3_immodules_query" > "$APPDIR/$gtk3_immodules_cache_file"
else
    echo "Warning: gtk-query-immodules-3.0 not found"
fi
if [ ! -f "$APPDIR/$gtk3_immodules_cache_file" ]; then
    echo "Warning: immodules.cache file is missing"
fi

echo "Installing GDK PixBufs"
gdk_libdir="$("$PKG_CONFIG" --variable=libdir gdk-pixbuf-2.0)"
gdk_pixbuf_binarydir="$("$PKG_CONFIG" --variable=gdk_pixbuf_binarydir gdk-pixbuf-2.0)"
gdk_pixbuf_cache_file="$("$PKG_CONFIG" --variable=gdk_pixbuf_cache_file gdk-pixbuf-2.0)"
gdk_pixbuf_moduledir="$("$PKG_CONFIG" --variable=gdk_pixbuf_moduledir gdk-pixbuf-2.0)"
# Note: gdk_pixbuf_query_loaders variable is not defined on some systems
gdk_pixbuf_query="$(search_tool "gdk-pixbuf-query-loaders" "gdk-pixbuf-2.0")"
copy_tree "$gdk_pixbuf_binarydir" "$APPDIR/"
cat >> "$HOOKFILE" <<EOF
export GDK_PIXBUF_MODULEDIR="\$APPDIR/$gdk_pixbuf_moduledir"
export GDK_PIXBUF_MODULE_FILE="\$CACHEDIR/loaders.cache"
sed "s|$gdk_pixbuf_moduledir|\$APPDIR/$gdk_pixbuf_moduledir|g" "\$APPDIR/$gdk_pixbuf_cache_file" > "\$GDK_PIXBUF_MODULE_FILE"
EOF
if [ -x "$gdk_pixbuf_query" ]; then
    echo "Updating pixbuf cache in $APPDIR/$gdk_pixbuf_cache_file"
    "$gdk_pixbuf_query" > "$APPDIR/$gdk_pixbuf_cache_file"
else
    echo "Warning: gdk-pixbuf-query-loaders not found"
fi
if [ ! -f "$APPDIR/$gdk_pixbuf_cache_file" ]; then
    echo "Warning: loaders.cache file is missing"
fi

echo "Copying more libraries"
gobject_libdir="$("$PKG_CONFIG" --variable=libdir gobject-2.0)"
gio_libdir="$("$PKG_CONFIG" --variable=libdir gio-2.0)"
librsvg_libdir="$("$PKG_CONFIG" --variable=libdir librsvg-2.0)"
FIND_ARRAY=(
    "$gdk_libdir"     "libgdk_pixbuf-*.so*"
    "$gobject_libdir" "libgobject-*.so*"
    "$gio_libdir"     "libgio-*.so*"
    "$librsvg_libdir" "librsvg-*.so*"
)
LIBRARIES=()
for (( i=0; i<${#FIND_ARRAY[@]}; i+=2 )); do
    directory=${FIND_ARRAY[i]}
    library=${FIND_ARRAY[i+1]}
    while IFS= read -r -d '' file; do
        LIBRARIES+=(--library="$file")
    done < <(find "$directory" \( -type l -o -type f \) -name "$library" -print0)
done
"$LINUXDEPLOY" --appdir="$APPDIR" "${LIBRARIES[@]}"

echo "Manually setting rpath for GTK modules"
PATCH_ARRAY=(
    "$gtk3_immodulesdir"
    "$gtk3_printbackendsdir"
    "$gdk_pixbuf_moduledir"
)
for directory in "${PATCH_ARRAY[@]}"; do
    while IFS= read -r -d '' file; do
        # shellcheck disable=SC2016
        patchelf --set-rpath '$ORIGIN/../../../..' "$APPDIR/$file"
    done < <(find "$directory" -name '*.so' -print0)
done

echo "Add a wrapper for some binaries"
# Note: some files on system must not be started with overrides above
# See https://github.com/linuxdeploy/linuxdeploy-plugin-gtk/issues/11#issuecomment-761788064
BINDIR="$APPDIR/usr/bin"
EOAFILE="$BINDIR/exec-outside-appimage"
mkdir -p "$BINDIR"
cat > "$EOAFILE" <<\EOF
#! /bin/bash

export PATH="$OLDPATH"

unset OLDPATH
unset GTK_DATA_PREFIX
unset GTK_THEME
unset GDK_BACKEND
unset XDG_DATA_DIRS
unset GSETTINGS_SCHEMA_DIR
unset GTK_EXE_PREFIX
unset GTK_PATH
unset GTK_IM_MODULE_DIR
unset GTK_IM_MODULE_FILE
unset GDK_PIXBUF_MODULEDIR
unset GDK_PIXBUF_MODULE_FILE

# Enter 'if' when '$0' is 'exec-outside-appimage' script itself
# Symbolic links to 'exec-outside-appimage' should not enter in 'if'
app="$(basename "$0")"
if ! command -v "$app" &> /dev/null; then
    app="$1"
    shift
    if [ -z "$app" ]; then
        echo "$0: this script requires a command as argument"
        exit 1
    elif ! command -v "$app" &> /dev/null; then
        echo "'$app' not found in PATH ($PATH)"
        exit 1
    fi
fi
"$app" "$@"
EOF
chmod $verbose 755 "$EOAFILE"
EOA_ARRAY=(
    "xdg-open"
    "eog"
)
for file in "${EOA_ARRAY[@]}"; do
    ln $verbose -s "$(basename "$EOAFILE")" "$BINDIR/$file"
done
