#!/usr/bin/env bash
# apk-make-index.sh - Generate signed packages.adb for an APK package directory
#
# Usage: apk-make-index.sh <package_directory> [sign_key]

set -eu

pkg_dir="${1:-.}"
sign_key="${2:-}"

if [ ! -d "$pkg_dir" ]; then
    echo "Usage: apk-make-index.sh <package_directory> [sign_key]" >&2
    exit 1
fi

cd "$pkg_dir"

mapfile -t apk_files < <(find . -maxdepth 1 -name '*.apk' -printf '%f\n' | sort)

if [ "${#apk_files[@]}" -eq 0 ]; then
    echo "No .apk files found in $(pwd)" >&2
    exit 0
fi

mkndx_args=(--allow-untrusted -o packages.adb)
if [ -n "$sign_key" ]; then
    mkndx_args+=(--sign-key "$sign_key")
    echo "Generating signed APKINDEX for $(pwd) (${#apk_files[@]} packages)" >&2
else
    echo "Generating unsigned APKINDEX for $(pwd) (${#apk_files[@]} packages)" >&2
fi

apk mkndx "${mkndx_args[@]}" "${apk_files[@]}"
