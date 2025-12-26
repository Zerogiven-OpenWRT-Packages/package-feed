#!/bin/sh

echo ""

# Get OpenWRT version
V=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2 | cut -d'.' -f1,2)
# Get CPU arch
A=$(opkg print-architecture | grep -v all | tail -1 | awk '{print $2}')
# Get target/subtarget
T=$(grep DISTRIB_TARGET /etc/openwrt_release | cut -d"'" -f2)

PACKAGES_FEED="https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/packages/$A"
KMODS_FEED="https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/kmods/$T"

PACKAGES_FEED_RETURN=`curl -s $PACKAGES_FEED`
KMODS_FEED_RETURN=`curl -s $KMODS_FEED`

if [ ! -z "$PACKAGES_FEED_RETURN" ] && [ ! -z "$KMODS_FEED_RETURN" ]; then
    echo "No feeds found for:"
    echo "$PACKAGES_FEED"
    echo "$KMODS_FEED"
    exit 0
fi

echo "Add feed(s) and public key and update opkg. Please wait..."

# check if curl returns empty on raw if path exists
if [ "" == "$PACKAGES_FEED_RETURN" ]; then
    # Add packages feed
    grep -q Zerogiven_Feed /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_Feed $PACKAGES_FEED" >> /etc/opkg/customfeeds.conf
else
    echo "No feed found for $PACKAGES_FEED"
fi

if [ "" == "$KMODS_FEED_RETURN" ]; then
    # Add kmods
    grep -q Zerogiven_Kmod_Feed /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_Kmod_Feed $KMODS_FEED" >> /etc/opkg/customfeeds.conf
else
    echo "No feed found for $KMODS_FEED"
fi

# Add public key
wget -qO /tmp/key.pub https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.pub && opkg-key add /tmp/key.pub

opkg --verbosity=0 update

echo "Feed(s) added and opkg updated. Ready to install packages from the feed."
echo ""
