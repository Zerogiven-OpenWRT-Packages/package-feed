# Zerogiven OpenWRT Package Feed

Custom package feed for OpenWRT containing various packages and kernel modules.

## Quick Setup (Copy & Paste)

Run these commands on your OpenWRT router:

```bash
# Add packages feed
grep -q Zerogiven_Feed /etc/opkg/customfeeds.conf || echo 'src/gz Zerogiven_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/<OpenWRT_Version>/packages/<cpu_arch>' >> /etc/opkg/customfeeds.conf

# Add kmods feed (optional, only if you need kernel modules)
grep -q Zerogiven_Kmod_Feed /etc/opkg/customfeeds.conf || echo 'src/gz Zerogiven_Kmod_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/<OpenWRT_Version>/kmods/<target>/<subtarget>' >> /etc/opkg/customfeeds.conf

# Add public key
wget https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.pub -O /tmp/Zerogiven_Feed.pub
opkg-key add /tmp/Zerogiven_Feed.pub

# Update package lists
opkg update
```

**Replace the placeholders:**
- `<OpenWRT_Version>` - Your OpenWRT version (e.g., `23.05`, `24.10`)
- `<cpu_arch>` - Your CPU architecture (e.g., `x86_64`, `aarch64_cortex-a53`)
- `<target>` - Your target platform (e.g., `x86`, `mediatek`, `bcm27xx`)
- `<subtarget>` - Your subtarget (e.g., `64`, `filogic`, `bcm2710`)

## Manual Setup

### 1. Add Feed to customfeeds.conf

Edit `/etc/opkg/customfeeds.conf` and add:

```
# Packages
src/gz Zerogiven_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/<OpenWRT_Version>/packages/<cpu_arch>

# Kernel modules (optional)
src/gz Zerogiven_Kmod_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/<OpenWRT_Version>/kmods/<target>/<subtarget>
```

### 2. Add Public Key

```bash
wget https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.pub -O /tmp/Zerogiven_Feed.pub
opkg-key add /tmp/Zerogiven_Feed.pub
```

### 3. Update Package Lists

```bash
opkg update
```

## Finding Your Device Info

To find your device's architecture and target, run on your router:

```bash
# CPU Architecture
opkg print-architecture | grep -v "all" | tail -1 | awk '{print $2}'

# Target/Subtarget
cat /etc/openwrt_release | grep DISTRIB_TARGET | cut -d"'" -f2
```
