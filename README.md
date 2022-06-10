# linuxdeploy-plugin-gtk

This is an (as of yet experimental) plugin for linuxdeploy. Its job is to bundle additional resources for applications that use GTK, and for common dependencies. Those involve GLib schemas for instance.

## Dependencies

This plugin requires the following dependencies in order to work properly:

- `file` command
- `find` command
- `pkg-config` or `pkgconf` command
- librsvg2 development files
- GTK development files

## Usage

```bash
# get linuxdeploy and linuxdeploy-plugin-gtk
> wget -c "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh"
> wget -c "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"

# get list of variables
> ./linuxdeploy-plugin-gtk.sh --help 

# first option: install your app into your AppDir via `make install` etc.
# second option: bundle your app's main executables manually
# see https://docs.appimage.org/packaging-guide/from-source/native-binaries.html for more information
> [...]

# call through linuxdeploy
> ./linuxdeploy-x86_64.AppImage --appdir AppDir --plugin gtk --output appimage --icon-file mypackage.png --desktop-file mypackage.desktop
```
## How it Works

This plugin is written in bash and goes through a series of steps to make sure
that all the libraries and other files are pulled in for GTK apps to work
properly once in the AppImage. The steps include:

1.  Detects the GTK version to use
2.  Installs itself as a hook in $APPDIR/apprun-hooks
3.  Uses gsettings to set a light or dark adwaita theme
4.  Installs the GLib schemas and then runs `glib-compile-schemas` on them
5.  Installs the GIRepository typelibs for gobject-introspection
6.  Copies the GTK libs and sets GTK path related environmental variables to
    locations in the APPDIR
7.  Updates the input method module registration (immodules) cache
8.  Installs the GDK Pixbuf libraries and cache, and then updates the cache
    using gdk-pixbuf-query-loaders
9.  Installs additional libraries including Gdk, GObject, Gio, librsvg, Pango,
    PangoCairo, and PangoFT2
10. Manually sets the RPATH for the GTK modules
