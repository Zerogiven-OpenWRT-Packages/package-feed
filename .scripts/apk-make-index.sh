#!/usr/bin/env bash
# apk-make-index.sh - Generate APKINDEX.tar.gz for an APK package directory
#
# Usage: apk-make-index.sh <package_directory>

set -eu

pkg_dir="${1:-.}"

if [ ! -d "$pkg_dir" ]; then
    echo "Usage: apk-make-index.sh <package_directory>" >&2
    exit 1
fi

cd "$pkg_dir"

mapfile -t apk_files < <(find . -maxdepth 1 -name '*.apk' -printf '%f\n' | sort)

if [ "${#apk_files[@]}" -eq 0 ]; then
    echo "No .apk files found in $(pwd)" >&2
    exit 0
fi

echo "Generating APKINDEX for $(pwd) (${#apk_files[@]} packages)" >&2
apk mkindex --output APKINDEX.tar.gz "${apk_files[@]}"
