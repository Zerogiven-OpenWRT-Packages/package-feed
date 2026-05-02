#!/usr/bin/env bash
# apk-sign.sh - Sign APKINDEX.tar.gz using APK's prepended-signature format
#
# Usage: apk-sign.sh <private_key.rsa> <APKINDEX.tar.gz>
#
# Replicates abuild-sign using only openssl + coreutils (no Alpine SDK required).
#
# APK's signed index format: a tar entry named .SIGN.RSA.<pubkeyname> containing
# an RSA/SHA1 signature is prepended to the original APKINDEX.tar.gz stream.
# APK locates the matching public key in /etc/apk/keys/ by that filename.

set -eu

if [ $# -lt 2 ]; then
    echo "Usage: apk-sign.sh <private_key.rsa> <APKINDEX.tar.gz>" >&2
    exit 1
fi

KEY_PATH="$1"
INDEX_PATH="$2"

KEY_BASE=$(basename "$KEY_PATH")
# Convention: Zerogiven_Feed.rsa -> .SIGN.RSA.Zerogiven_Feed.rsa.pub
SIG_FILENAME=".SIGN.RSA.${KEY_BASE}.pub"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# RSA/SHA1 signature — matches Alpine's abuild-sign behaviour
openssl dgst -sha1 -sign "$KEY_PATH" -out "$TMPDIR/sig.bin" "$INDEX_PATH"

cp "$TMPDIR/sig.bin" "$TMPDIR/$SIG_FILENAME"
# Strip the two 512-byte EOA blocks that `tar -c` appends — APK treats them as
# the end of the stream and would stop reading before the APKINDEX data.
tar -c --posix -C "$TMPDIR" "$SIG_FILENAME" | head -c -1024 > "$TMPDIR/sig.tar"

# Prepend the signature tar stream to the original index
cat "$TMPDIR/sig.tar" "$INDEX_PATH" > "$INDEX_PATH.signed"
mv "$INDEX_PATH.signed" "$INDEX_PATH"

echo "Signed $(basename "$INDEX_PATH") with $SIG_FILENAME" >&2
