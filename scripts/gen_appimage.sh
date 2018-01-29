#!/bin/bash

########################################################################
# Package the binaries built as an AppImage
# By Simon Peter 2016
# For more information, see http://appimage.org/
########################################################################

# App arch, used by generate_appimage.
if [ -z "$ARCH" ]; then
  export ARCH="$(arch)"
fi

# App name, used by generate_appimage.
APP=mikutter
VERSION=$(git describe --tags)

ROOT_DIR="$PWD"
APP_DIR="$PWD/$APP.AppDir"

echo "--> get ruby source"
wget https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.6.tar.gz
tar xf ruby-2.3.6.tar.gz

echo "--> compile Ruby and install it into AppDir"
pushd ruby-2.3.6
./configure "--prefix=$APP_DIR/usr"
make -j2
make install
popd

echo "--> install gems"
./$APP_DIR/usr/bin/gem install bundler
./$APP_DIR/usr/bin/bundle install

echo "--> remove doc, man, ri"
rm -rf "$APP_DIR/usr/share"

echo "--> copy mikutter"
mkdir -p $APP_DIR/usr/share/mikutter
cp core mikutter.rb $APP_DIR/usr/share/mikutter
cat > $APP_DIR/usr/bin/mikutter << EOF
#!/bin/sh

export DISABLE_BUNDLER_SETUP=1
exec bin/ruby share/mikutter/mikutter.rb "\$@"
EOF
chmod a+x $APP_DIR/usr/bin/mikutter

echo "--> get helper functions"
wget -q https://github.com/AppImage/AppImages/raw/master/functions.sh -O ./functions.sh
. ./functions.sh

echo "--> patch away absolute paths"
patch_strings_in_file "$APP_DIR/usr/bin/ruby" "$APP_DIR/usr" "."

pushd "$APP_DIR"

echo "--> get AppRun"
get_apprun

echo "--> get desktop file and icon"
cp $ROOT_DIR/$APP.desktop .
cp $ROOT_DIR/core/skin/data/icon.png $APP.png

echo "--> get desktop integration"
get_desktopintegration $APP

echo "--> copy dependencies"
copy_deps

echo "--> move the libraries to usr/bin"
move_lib

echo "--> delete stuff that should not go into the AppImage."
delete_blacklisted

popd

echo "--> enable fuse"
sudo modprobe fuse
sudo usermod -a -G fuse $(whoami)

echo "--> generate AppImage"
#   - Expects: $ARCH, $APP, $VERSION env vars
#   - Expects: ./$APP.AppDir/ directory
#   - Produces: ../out/$APP-$VERSION.glibc$GLIBC_NEEDED-$ARCH.AppImage
generate_appimage

echo "--> generated $APP-$VERSION-$ARCH.AppImage"
mv ../out/*.AppImage "$TRAVIS_BUILD_DIR/${APP}-${VERSION}-${ARCH}.AppImage"

echo '==> finished'
