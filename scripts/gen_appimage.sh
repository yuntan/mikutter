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
# use relative load paths at run time
./configure --enable-load-relative --prefix=/usr
make -j2
make "DESTDIR=$APP_DIR" install
popd

echo "--> install gems"
# for Travis CI, disable RVM
GEM_DIR=$APP_DIR/usr/lib/ruby/gems/2.3.0
GEM_HOME=$GEM_DIR GEM_PATH=$GEM_DIR $APP_DIR/usr/bin/ruby $APP_DIR/usr/bin/gem install bundler
GEM_HOME=$GEM_DIR GEM_PATH=$GEM_DIR $APP_DIR/usr/bin/ruby $APP_DIR/usr/bin/bundle install

echo "--> remove doc, man, ri"
rm -rf "$APP_DIR/usr/share"

echo "--> copy mikutter"
mkdir -p $APP_DIR/usr/share/mikutter
cp -a core mikutter.rb $APP_DIR/usr/share/mikutter
cat > $APP_DIR/usr/bin/mikutter << EOF
#!/bin/sh

export DISABLE_BUNDLER_SETUP=1
export GI_TYPELIB_PATH=\$PWD/lib/girepository-1.0
exec bin/ruby share/mikutter/mikutter.rb "\$@"
EOF
chmod a+x $APP_DIR/usr/bin/mikutter

echo "--> get helper functions"
wget -q https://github.com/AppImage/AppImages/raw/master/functions.sh -O ./functions.sh
. ./functions.sh

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

# copy Typelibs for gobject-introspection gem
cp -av /usr/lib/girepository-* usr/lib

echo "--> patch away absolute paths"
# for gobject-introspection gem
# find usr/lib -name libgirepository-1.0.so.1 -exec sed -i -e 's|/usr/lib/girepository-1.0|.////lib/girepository-1.0|g' {} \;

echo "--> move the libraries to usr/lib"
move_lib

echo "--> delete stuff that should not go into the AppImage."
delete_blacklisted

# TODO should we remove libssl and libcrypto?
# additional_exclude="libssl.so.1 libssl.so.1.0.0 libcrypto.so.1 libcrypto.so.1.0.0"
# for f in $additional_exclude; do
#   found="$(find . -name "$f" -not -path "./usr/optional/*")"
#   for f2 in $found; do
#     rm -vf "$f2" "$(readlink -f "$f2")"
#   done
# done

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
