#! /bin/bash

# abort on all errors
set -e

if [ "$DEBUG" != "" ]; then
    set -x
fi

script=$(readlink -f "$0")

show_usage() {
    echo "Usage: $script --appdir <path to AppDir>"
    echo
    echo "Bundles resources for applications that use Gtk 2 or 3 into an AppDir"
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

pushd "$APPDIR"

# source: https://github.com/AppImage/pkg2appimage/blob/3168d7ce787246feb697a950005fbffec0533def/legacy/pinta/Recipe#L41
mkdir -p usr/share/glib-2.0/schemas/
pushd usr/share/glib-2.0/schemas/
ln -s /usr/share/glib-2.0/schemas/gschemas.compiled .
popd
