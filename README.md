# Zerogiven OpenWRT Package Feed

Custom package feed for OpenWRT containing various packages and kernel modules.

> Note: This feed is in an early beginning stage so it could happen that directory structure changes and your feed not updating anymore. If that is the case remove all existing `Zerogiven_*` entries from `/etc/opkg/customfeeds.conf` and re-run the next setup step.

## Automated Setup (setup.sh)

The script does at least same things like the steps below but with this one liner you can fasten your setup:

```bash
wget -qO - https://raw.githubusercontent.com/Zerogiven-OpenWRT-Packages/package-feed/refs/heads/main/setup.sh | sh
```

## Quick Setup (Copy & Paste)

Run these commands on your OpenWRT router:

```bash
# Get OpenWRT version (minor for packages, patch for kmods)
V=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2 | cut -d'.' -f1,2)
VP=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2)
# Get CPU arch
A=$(opkg print-architecture | grep -v all | tail -1 | awk '{print $2}')
# Get target/subtarget
T=$(grep DISTRIB_TARGET /etc/openwrt_release | cut -d"'" -f2)

# Add arch-specific packages
grep -q Zerogiven_Feed /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/packages/$A" >> /etc/opkg/customfeeds.conf
# Add arch-independent packages (LuCI apps, etc.)
grep -q Zerogiven_All /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_All https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/all" >> /etc/opkg/customfeeds.conf
# Add kmods (optional) - uses patch version (e.g., 24.10.3)
grep -q Zerogiven_Kmod_Feed /etc/opkg/customfeeds.conf || echo "src/gz Zerogiven_Kmod_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/kmods/$VP/$T" >> /etc/opkg/customfeeds.conf

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

# Kernel modules (optional) - requires patch version!
src/gz Zerogiven_Kmod_Feed https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/kmods/<OpenWRT_Patch_Version>/<target>/<subtarget>
```

**Replace the placeholders:**
- `<OpenWRT_Version>` - Your OpenWRT minor version (e.g., `23.05`, `24.10`)
- `<OpenWRT_Patch_Version>` - Your OpenWRT full version including patch (e.g., `24.10.3`)
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
| `Zerogiven_Kmod_Feed` | `kmods/<patch_version>/<target>/<subtarget>/` | Kernel modules (tied to specific kernel version) |

> **Note:** Kernel modules require the full patch version (e.g., `24.10.3`) because they are compiled against a specific kernel version. Regular packages use the minor version (e.g., `24.10`).

## Available Packages

<!-- PACKAGES_TABLE_START -->

| Package | Description | Version | OpenWRT | Arch |
|---------|-------------|---------|---------|------|
| [gpio-fan-rpm](https://github.com/Zerogiven-OpenWRT-Packages/gpio-fan-rpm) | High-precision command-line utility for measuring fan RPM using GPIO pins on ... | 2.2.0-r1 | 24.10 | aarch64, arm, mipsel, x86_64 |
| [kmod-quectel-rm520n-thermal](https://github.com/Zerogiven-OpenWRT-Packages/Quectel-RM520N-Thermal) | Kernel modules for monitoring and managing the Quectel RM520N modem temperature. | 6.6.93.1.4.0-r1 | 24.10 | aarch64, arm, x86_64 |
| [luci-app-podman](https://github.com/Zerogiven-OpenWRT-Packages/luci-app-podman) | Modern web interface for managing Podman containers with auto-update, auto-st... | 1.11.1-r1 | 24.10 | all |
| [prometheus-node-exporter-lua-podman](https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman) | Basic Podman metrics collector for prometheus-node-exporter-lua. | 1.0.0-r1 | 24.10 | aarch64, arm, mips, mipsel, x86_64 |
| [prometheus-node-exporter-lua-podman-container](https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman) | Per-container stats collector for prometheus-node-exporter-lua. | 1.0.0-r1 | 24.10 | aarch64, arm, mips, mipsel, x86_64 |
| [prometheus-node-exporter-lua-quectel-rm520n-thermal](https://github.com/Zerogiven-OpenWRT-Packages/Quectel-RM520N-Thermal) | Lua collector for prometheus-node-exporter-lua that exports | 1.4.0-r1 | 24.10 | aarch64, arm, x86_64 |
| [quectel-rm520n-thermal](https://github.com/Zerogiven-OpenWRT-Packages/Quectel-RM520N-Thermal) | Tools and configuration for managing the Quectel RM520N modem temperature. | 1.4.0-r1 | 24.10 | aarch64, arm, x86_64 |
| [reaction](https://github.com/Zerogiven-OpenWRT-Packages/reaction) | A daemon that scans program outputs for repeated patterns, and takes action. | 2.2.1-r5 | 23.05, 24.10 | aarch64, arm, x86_64 |

<!-- PACKAGES_TABLE_END -->

## Finding Your Device Info

To find your device's architecture, target, and version, run on your router:

```bash
# OpenWRT Version (minor, e.g., 24.10)
grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2 | cut -d'.' -f1,2

# OpenWRT Patch Version (for kmods, e.g., 24.10.3)
grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2

# CPU Architecture
opkg print-architecture | grep -v "all" | tail -1 | awk '{print $2}'

# Target/Subtarget
grep DISTRIB_TARGET /etc/openwrt_release | cut -d"'" -f2
```
