# linuxdeploy-plugin-gtk

This is an (as of yet experimental) plugin for linuxdeploy. Its job is to bundle additional resources for applications that use Gtk+ 2 or 3, and for common dependencies. Those involve GLib schemas for instance.


## Usage

```bash
# get linuxdeploy and linuxdeploy-plugin-gtk
> wget -c "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh"
> wget -c "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"

# first option: install your app into your AppDir via `make install` etc.
# second option: bundle your app's main executables manually
# see https://docs.appimage.org/packaging-guide/from-source/native-binaries.html for more information
> [...]

# call through linuxdeploy
> ./linuxdeploy-x86_64.AppImage --appdir AppDir --plugin gtk --output appimage --icon-file mypackage.png --desktop-file mypackage.desktop
```
