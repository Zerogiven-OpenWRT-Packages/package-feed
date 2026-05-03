#!/bin/sh

echo ""

# Get OpenWRT version (minor version for packages, e.g., 24.10 or 25.12)
V=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2 | cut -d'.' -f1,2)
# Get OpenWRT patch version for kmods (e.g., 24.10.3 or 25.12.1)
VP=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2)
# Get target/subtarget
T=$(grep DISTRIB_TARGET /etc/openwrt_release | cut -d"'" -f2)

# Detect package manager: apk (OpenWRT >= 25.12) or opkg (<= 24.10)
V_MAJOR=$(echo "$V" | cut -d'.' -f1)
if [ "$V_MAJOR" -ge 25 ] || command -v apk >/dev/null 2>&1; then
    USE_APK=1
else
    USE_APK=0
fi

# Get CPU architecture (method depends on package manager)
if [ "$USE_APK" -eq 1 ]; then
    A=$(cat /etc/apk/arch 2>/dev/null || apk --print-arch 2>/dev/null)
else
    A=$(opkg print-architecture | grep -v all | tail -1 | awk '{print $2}')
fi

if [ -z "$A" ]; then
    echo "Error: could not determine CPU architecture" >&2
    exit 1
fi

PACKAGES_FEED="https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/packages/$A/packages.adb"
ALL_FEED="https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/all/packages.adb"
KMODS_FEED="https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/kmods/$VP/$T/packages.adb"

PACKAGES_FEED_RETURN=$(curl -s "$PACKAGES_FEED")
ALL_FEED_RETURN=$(curl -s "$ALL_FEED")
KMODS_FEED_RETURN=$(curl -s "$KMODS_FEED")

echo "Add feed(s) and public key and update packages. Please wait..."

if [ "$USE_APK" -eq 1 ]; then
    # OpenWRT >= 25.12: configure apk feeds in /etc/apk/repositories.d/customfeeds.list
    mkdir -p /etc/apk/repositories.d
    CUSTOMFEEDS="/etc/apk/repositories.d/customfeeds.list"

    if [ "" = "$PACKAGES_FEED_RETURN" ]; then
        grep -q "$PACKAGES_FEED" "$CUSTOMFEEDS" 2>/dev/null || \
            echo "$PACKAGES_FEED" >> "$CUSTOMFEEDS"
        echo "Added: $PACKAGES_FEED"
    else
        echo "No feed found for $PACKAGES_FEED"
    fi

    if [ "" = "$ALL_FEED_RETURN" ]; then
        grep -q "$ALL_FEED" "$CUSTOMFEEDS" 2>/dev/null || \
            echo "$ALL_FEED" >> "$CUSTOMFEEDS"
        echo "Added: $ALL_FEED"
    else
        echo "No feed found for $ALL_FEED"
    fi

    if [ "" = "$KMODS_FEED_RETURN" ]; then
        grep -q "$KMODS_FEED" "$CUSTOMFEEDS" 2>/dev/null || \
            echo "$KMODS_FEED" >> "$CUSTOMFEEDS"
        echo "Added: $KMODS_FEED"
    else
        echo "No feed found for $KMODS_FEED"
    fi

    # Install public key — APK loads all *.rsa.pub files from /etc/apk/keys/ automatically
    mkdir -p /etc/apk/keys
    wget -qO /etc/apk/keys/Zerogiven_Feed.rsa.pub \
        https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.rsa.pub

    apk update

else
    # OpenWRT <= 24.10: configure opkg feeds in /etc/opkg/customfeeds.conf

    if [ "" = "$PACKAGES_FEED_RETURN" ]; then
        grep -q Zerogiven_Packages /etc/opkg/customfeeds.conf || \
            echo "src/gz Zerogiven_Packages $PACKAGES_FEED" >> /etc/opkg/customfeeds.conf
        echo "Added: Zerogiven_Packages"
    else
        echo "No feed found for $PACKAGES_FEED"
    fi

    if [ "" = "$ALL_FEED_RETURN" ]; then
        grep -q Zerogiven_All /etc/opkg/customfeeds.conf || \
            echo "src/gz Zerogiven_All $ALL_FEED" >> /etc/opkg/customfeeds.conf
        echo "Added: Zerogiven_All"
    else
        echo "No feed found for $ALL_FEED"
    fi

    if [ "" = "$KMODS_FEED_RETURN" ]; then
        grep -q Zerogiven_Kmods /etc/opkg/customfeeds.conf || \
            echo "src/gz Zerogiven_Kmods $KMODS_FEED" >> /etc/opkg/customfeeds.conf
        echo "Added: Zerogiven_Kmods"
    else
        echo "No feed found for $KMODS_FEED"
    fi

    # Add public key
    wget -qO /tmp/key.pub \
        https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.pub && \
        opkg-key add /tmp/key.pub

    opkg --verbosity=0 update

fi

echo "Feed(s) added and packages updated. Ready to install packages from the feed."
echo ""
