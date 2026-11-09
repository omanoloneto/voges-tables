#!/usr/bin/env bash
set -euo pipefail

version="${1:?version, such as 1.0.0}"
bundle="${2:?build/linux/x64/release/bundle folder}"
output="${3:?output .deb file}"

here="$(cd "$(dirname "$0")" && pwd)"
app_id=com.omanoloneto.voges_tables
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
chmod 755 "$root"

mkdir -p "$root/DEBIAN" "$root/usr/lib/voges-tables" "$root/usr/bin" \
  "$root/usr/share/applications" "$root/usr/share/icons/hicolor/256x256/apps"
cp -r "$bundle/." "$root/usr/lib/voges-tables/"
ln -s ../lib/voges-tables/voges_tables "$root/usr/bin/voges-tables"
install -m 644 "$here/$app_id.desktop" "$root/usr/share/applications/"
convert "$here/../../assets/icon/icon_rounded.png" -resize 256x256 \
  "$root/usr/share/icons/hicolor/256x256/apps/$app_id.png"

# zenity (or kdialog) provides the open and save dialogs for file_picker
cat > "$root/DEBIAN/control" <<CONTROL
Package: voges-tables
Version: $version
Section: office
Priority: optional
Architecture: amd64
Depends: libgtk-3-0t64 | libgtk-3-0, zenity | kdialog
Maintainer: omanoloneto <mano.afonso93@gmail.com>
Homepage: https://omanoloneto.pro/voges/tables/
Description: simple spreadsheet
 Voges Tables edits spreadsheets with formulas in English, Portuguese
 and Spanish, number formats, borders, colors and several sheets, opens
 XLSX, XLSM, CSV, TSV and plain text files and saves XLSX and CSV.
CONTROL

dpkg-deb --build --root-owner-group "$root" "$output"
