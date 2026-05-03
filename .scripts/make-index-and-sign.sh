#! /usr/bin/env bash

set -eu

usage_exit() {
        echo "Usage: $0 [-s USIGN_SECRET] [-k APK_SIGN_KEY] TARGET_DIR" 1>&2
        exit 1
}

while getopts s:k:h OPT
do
    case $OPT in
        s)  USIGN_SECRET_PATH=$OPTARG
            ;;
        k)  APK_SIGN_KEY_PATH=$OPTARG
            ;;
        h)  usage_exit
            ;;
        \?) usage_exit
            ;;
    esac
done

export PATH=$(realpath ./.scripts/):$PATH

shift $((OPTIND - 1))

if [[ -v USIGN_SECRET_PATH ]] ; then
    USIGN_SECRET_PATH=$(realpath "$USIGN_SECRET_PATH")
fi
if [[ -v APK_SIGN_KEY_PATH ]] ; then
    APK_SIGN_KEY_PATH=$(realpath "$APK_SIGN_KEY_PATH")
fi
TARGET_DIR=${1:-.}

make_ipk_index_and_sign() {
  local CURRENT_DIR
  CURRENT_DIR=$(pwd)
  echo "$1"
  cd "$1"
  ipkg-make-index.sh . > ./Packages
  gzip -9c ./Packages > ./Packages.gz
  if [[ -v USIGN_SECRET_PATH ]] ; then
      usign -S -m ./Packages -s "$USIGN_SECRET_PATH" -x ./Packages.sig
      usign -S -m ./Packages.gz -s "$USIGN_SECRET_PATH" -x ./Packages.gz.sig
  fi
  cd "$CURRENT_DIR"
}

make_apk_index_and_sign() {
  local CURRENT_DIR
  CURRENT_DIR=$(pwd)
  echo "$1"
  cd "$1"
  apk-make-index.sh .
  if [[ -v APK_SIGN_KEY_PATH ]] ; then
      apk-sign.sh "$APK_SIGN_KEY_PATH" ./packages.adb
  fi
  cd "$CURRENT_DIR"
}

for dir in $(find "$TARGET_DIR" \( -name '*.ipk' -o -name '*.apk' \) -exec dirname {} \; | sort | uniq); do
  if ls "$dir"/*.ipk >/dev/null 2>&1; then
    make_ipk_index_and_sign "$dir"
  else
    make_apk_index_and_sign "$dir"
  fi
done
