# Zerogiven OpenWRT Package Feed

Custom package feed for OpenWRT containing various packages and kernel modules.

> **Note:** This feed is in an early beginning stage so it could happen that directory structure changes and your feed not updating anymore.
> - OpenWRT ≤ 24.10: remove all `Zerogiven_*` entries from `/etc/opkg/customfeeds.conf` and re-run setup.
> - OpenWRT ≥ 25.12: remove all Zerogiven feed lines from `/etc/apk/repositories.d/customfeeds.list` and re-run setup.

## Automated Setup (setup.sh)

The script automatically detects whether your router uses `opkg` (OpenWRT ≤ 24.10) or `apk` (OpenWRT ≥ 25.12) and configures the feeds accordingly:

```bash
wget -qO - https://raw.githubusercontent.com/Zerogiven-OpenWRT-Packages/package-feed/refs/heads/main/setup.sh | sh
```

## Quick Setup (Copy & Paste)

### OpenWRT ≥ 25.12 (apk)

```bash
# Get OpenWRT version (minor for packages, patch for kmods)
V=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2 | cut -d'.' -f1,2)
VP=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2)
# Get CPU arch
A=$(cat /etc/apk/arch 2>/dev/null || apk --print-arch)
# Get target/subtarget
T=$(grep DISTRIB_TARGET /etc/openwrt_release | cut -d"'" -f2)

# Add feeds to /etc/apk/repositories.d/customfeeds.list
mkdir -p /etc/apk/repositories.d
grep -q "package-feed/raw/main/$V/packages/$A" /etc/apk/repositories.d/customfeeds.list 2>/dev/null || \
  echo "https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/packages/$A/packages.adb" >> /etc/apk/repositories.d/customfeeds.list
grep -q "package-feed/raw/main/$V/all" /etc/apk/repositories.d/customfeeds.list 2>/dev/null || \
  echo "https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/$V/all/packages.adb" >> /etc/apk/repositories.d/customfeeds.list
# Kernel modules (optional)
grep -q "package-feed/raw/main/kmods/$VP/$T" /etc/apk/repositories.d/customfeeds.list 2>/dev/null || \
  echo "https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/kmods/$VP/$T/packages.adb" >> /etc/apk/repositories.d/customfeeds.list

# Add public key
mkdir -p /etc/apk/keys
wget -qO /etc/apk/keys/Zerogiven_Feed.rsa.pub https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.rsa.pub

apk update
```

### OpenWRT ≤ 24.10 (opkg)

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

### OpenWRT ≥ 25.12 (apk)

#### 1. Add Feeds to /etc/apk/repositories.d/customfeeds.list

Edit `/etc/apk/repositories.d/customfeeds.list` and add:

```
https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/<OpenWRT_Version>/packages/<cpu_arch>/packages.adb
https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/<OpenWRT_Version>/all/packages.adb
https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/kmods/<OpenWRT_Patch_Version>/<target>/<subtarget>/packages.adb
```

**Replace the placeholders:**
- `<OpenWRT_Version>` - Your OpenWRT minor version (e.g., `25.12`)
- `<OpenWRT_Patch_Version>` - Your OpenWRT full version including patch (e.g., `25.12.1`)
- `<cpu_arch>` - Your CPU architecture (e.g., `x86_64`, `aarch64_cortex-a53`)
- `<target>` - Your target platform (e.g., `x86`, `mediatek`)
- `<subtarget>` - Your subtarget (e.g., `64`, `filogic`)

#### 2. Add Public Key

```bash
mkdir -p /etc/apk/keys
wget https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.rsa.pub \
  -O /etc/apk/keys/Zerogiven_Feed.rsa.pub
```

#### 3. Update Package Lists

```bash
apk update
```

---

### OpenWRT ≤ 24.10 (opkg)

#### 1. Add Feeds to customfeeds.conf

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

#### 2. Add Public Key

```bash
wget https://github.com/Zerogiven-OpenWRT-Packages/package-feed/raw/main/Zerogiven_Feed.pub -O /tmp/Zerogiven_Feed.pub
opkg-key add /tmp/Zerogiven_Feed.pub
```

#### 3. Update Package Lists

```bash
opkg update
```

## Feed Structure

| Feed | Directory | Index File | Contents |
|------|-----------|------------|----------|
| Packages | `<version>/packages/<arch>/` | `packages.adb` / `Packages.gz` | Architecture-specific packages |
| All | `<version>/all/` | `packages.adb` / `Packages.gz` | Architecture-independent packages (LuCI apps, themes, translations) |
| Kmods | `kmods/<patch_version>/<target>/<subtarget>/` | `packages.adb` / `Packages.gz` | Kernel modules (tied to specific kernel version) |

> **Note:** OpenWRT ≥ 25.12 uses `packages.adb` (read by `apk`). OpenWRT ≤ 24.10 uses `Packages.gz` (read by `opkg`). Kernel modules require the full patch version because they are compiled against a specific kernel version.

## Available Packages

<!-- PACKAGES_TABLE_START -->

| Package | Description | Version | OpenWRT | Arch |
|---------|-------------|---------|---------|------|
| [gpio-fan-rpm](https://github.com/Zerogiven-OpenWRT-Packages/gpio-fan-rpm) | High-precision command-line utility for measuring fan RPM using GPIO pins on ... | 2.2.0-r2 | 24.10 | aarch64, arm, mips, mipsel, x86_64 |
| [kmod-quectel-rm520n-thermal](https://github.com/Zerogiven-OpenWRT-Packages/Quectel-RM520N-Thermal) | Kernel modules for monitoring and managing the Quectel RM520N modem temperature. | 6.6.73.1.4.1-r1 | 24.10 | aarch64, arm, x86_64 |
| [luci-app-podman](https://github.com/Zerogiven-OpenWRT-Packages/luci-app-podman) | Modern web interface for managing Podman containers with auto-update, auto-st... | 2.0.0-r1 | 24.10 | all |
| [prometheus-node-exporter-lua-podman](https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman) | Basic Podman metrics collector for prometheus-node-exporter-lua. | 1.0.1-r1 | 24.10 | aarch64, arm, mips, mipsel, x86_64 |
| [prometheus-node-exporter-lua-podman-container](https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman) | Per-container stats collector for prometheus-node-exporter-lua. | 1.0.1-r1 | 24.10 | aarch64, arm, mips, mipsel, x86_64 |
| [prometheus-node-exporter-lua-quectel-rm520n-thermal](https://github.com/Zerogiven-OpenWRT-Packages/Quectel-RM520N-Thermal) | Lua collector for prometheus-node-exporter-lua that exports | 1.4.1-r1 | 24.10 | aarch64, arm, x86_64 |
| [quectel-rm520n-thermal](https://github.com/Zerogiven-OpenWRT-Packages/Quectel-RM520N-Thermal) | Tools and configuration for managing the Quectel RM520N modem temperature. | 1.4.1-r1 | 24.10 | aarch64, arm, x86_64 |
| [reaction](https://github.com/Zerogiven-OpenWRT-Packages/reaction) | A daemon that scans program outputs for repeated patterns, and takes action. | 2.3.1-r1 | 23.05, 24.10 | aarch64, arm, x86_64 |

<!-- PACKAGES_TABLE_END -->

## Finding Your Device Info

### OpenWRT ≥ 25.12 (apk)

```bash
# OpenWRT Version (minor, e.g., 25.12)
grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2 | cut -d'.' -f1,2

# OpenWRT Patch Version (for kmods, e.g., 25.12.1)
grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2

# CPU Architecture
cat /etc/apk/arch

# Target/Subtarget
grep DISTRIB_TARGET /etc/openwrt_release | cut -d"'" -f2
```

### OpenWRT ≤ 24.10 (opkg)

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

## APK Signing Key Setup (Maintainers)

To enable APK package index signing, generate an RSA key pair and register the private key as a GitHub secret:

```bash
# Generate private key
openssl genrsa -out Zerogiven_Feed.rsa 4096

# Extract public key (RSA traditional format required by APK)
openssl rsa -in Zerogiven_Feed.rsa -out Zerogiven_Feed.rsa.pub -pubout

# Commit the public key to the repository
git add Zerogiven_Feed.rsa.pub
git commit -m "Add APK public signing key"

# Add the private key content as a GitHub secret named APK_SIGN_KEY
# (Settings → Secrets and variables → Actions → New repository secret)
cat Zerogiven_Feed.rsa  # copy this output into the secret value

# Delete the local private key — it lives only in GitHub Secrets
rm Zerogiven_Feed.rsa
```
