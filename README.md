# Zerogiven OpenWRT Package Feed

Custom package feed for OpenWRT containing various packages and kernel modules.

> Note: This feed is in an early beginning stage so it could happen that directory structure changes and your feed not updating anymore. If that is the case remove all existing `Zerogiven_*` entries from `/etc/opkg/customfeeds.conf` and re-run the next setup step.

## Automated Setup (setup.sh)

The script does at least same things like the steps below but with this one liner you can fasten your setup:

```bash
wget -qO - https://raw.githubusercontent.com/Zerogiven-OpenWRT-Packages/package-feed/refs/heads/main/setup.sh | bash
```

## Quick Setup (Copy & Paste)

Run these commands on your OpenWRT router:

```bash
# Get OpenWRT version
V=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2 | cut -d'.' -f1,2)
# Get CPU arch
A=$(opkg print-architecture | grep -v all | tail -1 | awk '{print $2}')
# Get target/subtarget
T=$(grep DISTRIB_TARGET /etc/openwrt_release | cut -d"'" -f2)

# Add arch-specific packages
grep -q Zerogiven_Feed /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/packages/$A" >> /etc/opkg/customfeeds.conf
# Add arch-independent packages (LuCI apps, etc.)
grep -q Zerogiven_All /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_All https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/all" >> /etc/opkg/customfeeds.conf
# Add kmods (optional)
grep -q Zerogiven_Kmod_Feed /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_Kmod_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/kmods/$T" >> /etc/opkg/customfeeds.conf

# Add public key
wget -qO /tmp/key.pub https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.pub && opkg-key add /tmp/key.pub

opkg update
```

## Manual Setup

### 1. Add Feeds to customfeeds.conf

Edit `/etc/opkg/customfeeds.conf` and add:

```
# Arch-specific packages
src/gz Zerogiven_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/<OpenWRT_Version>/packages/<cpu_arch>

# Arch-independent packages (LuCI apps, themes, translations, etc.)
src/gz Zerogiven_All https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/<OpenWRT_Version>/all

# Kernel modules (optional)
src/gz Zerogiven_Kmod_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/<OpenWRT_Version>/kmods/<target>/<subtarget>
```

**Replace the placeholders:**
- `<OpenWRT_Version>` - Your OpenWRT version (e.g., `23.05`, `24.10`)
- `<cpu_arch>` - Your CPU architecture (e.g., `x86_64`, `aarch64_cortex-a53`)
- `<target>` - Your target platform (e.g., `x86`, `mediatek`, `bcm27xx`)
- `<subtarget>` - Your subtarget (e.g., `64`, `filogic`, `bcm2710`)

### 2. Add Public Key

```bash
wget https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.pub -O /tmp/Zerogiven_Feed.pub
opkg-key add /tmp/Zerogiven_Feed.pub
```

### 3. Update Package Lists

```bash
opkg update
```

## Feed Structure

| Feed | Directory | Contents |
|------|-----------|----------|
| `Zerogiven_Feed` | `<version>/packages/<arch>/` | Architecture-specific packages |
| `Zerogiven_All` | `<version>/all/` | Architecture-independent packages (LuCI apps, themes, translations) |
| `Zerogiven_Kmod_Feed` | `<version>/kmods/<target>/<subtarget>/` | Kernel modules |

## Finding Your Device Info

To find your device's architecture and target, run on your router:

```bash
# CPU Architecture
opkg print-architecture | grep -v "all" | tail -1 | awk '{print $2}'

# Target/Subtarget
cat /etc/openwrt_release | grep DISTRIB_TARGET | cut -d"'" -f2
```
