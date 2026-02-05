#!/bin/sh

echo ""

# Get OpenWRT version (minor version for packages, e.g., 24.10)
V=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2 | cut -d'.' -f1,2)
# Get OpenWRT patch version for kmods (e.g., 24.10.3)
VP=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2)
# Get CPU arch
A=$(opkg print-architecture | grep -v all | tail -1 | awk '{print $2}')
# Get target/subtarget
T=$(grep DISTRIB_TARGET /etc/openwrt_release | cut -d"'" -f2)

PACKAGES_FEED="https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/packages/$A"
ALL_FEED="https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/all"
KMODS_FEED="https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/kmods/$VP/$T"

PACKAGES_FEED_RETURN=$(curl -s "$PACKAGES_FEED")
ALL_FEED_RETURN=$(curl -s "$ALL_FEED")
KMODS_FEED_RETURN=$(curl -s "$KMODS_FEED")

echo "Add feed(s) and public key and update opkg. Please wait..."

# Check if curl returns empty on raw if path exists
if [ "" = "$PACKAGES_FEED_RETURN" ]; then
    # Add packages feed
    grep -q Zerogiven_Packages /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_Packages $PACKAGES_FEED" >> /etc/opkg/customfeeds.conf
    echo "Added: Zerogiven_Packages"
else
    echo "No feed found for $PACKAGES_FEED"
fi

if [ "" = "$ALL_FEED_RETURN" ]; then
    # Add all packages feed
    grep -q Zerogiven_All /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_All $ALL_FEED" >> /etc/opkg/customfeeds.conf
    echo "Added: Zerogiven_All"
else
    echo "No feed found for $ALL_FEED"
fi

if [ "" = "$KMODS_FEED_RETURN" ]; then
    # Add kmods
    grep -q Zerogiven_Kmods /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_Kmods $KMODS_FEED" >> /etc/opkg/customfeeds.conf
    echo "Added: Zerogiven_Kmods"
else
    echo "No feed found for $KMODS_FEED"
fi

# Add public key
wget -qO /tmp/key.pub https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.pub && opkg-key add /tmp/key.pub

opkg --verbosity=0 update

echo "Feed(s) added and opkg updated. Ready to install packages from the feed."
echo ""
