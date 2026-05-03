#!/usr/bin/env bash
#
# sync-packages.sh - Synchronize incoming packages to the OpenWRT feed
#
# Usage: sync-packages.sh <incoming_dir>
#
# This script:
# 1. Parses incoming .ipk/.apk files to determine their type and destination
# 2. Distributes packages to appropriate directories:
#    - Regular packages: [version]/packages/[arch]/
#    - Kmod packages: kmods/[patch_version]/[target]/[subtarget]/
#    - All packages: [version]/all/
# 3. Removes older versions of packages (keeps only latest)
#
# Supported formats:
#   .ipk - OpenWRT <= 24.10
#   .apk - OpenWRT >= 25.12
#
# Both formats share the same filename convention:
#   Regular: {name}_{pkgver}_{arch}_{openwrt_ver}.ipk/.apk
#   All:     {name}_{pkgver}_all_{openwrt_ver}.ipk/.apk
#   Kmod:    kmod-{name}_{target}_{subtarget}_{arch}_{openwrt_patch_ver}.ipk/.apk
#

set -euo pipefail

shopt -s nullglob extglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

#######################################
# Extract package name from IPK filename (everything before first _)
# Arguments:
#   $1 - filename (basename only)
#######################################
extract_package_name() {
    local filename="$1"
    local base="${filename%.ipk}"
    base="${base%.apk}"
    echo "${base%%_*}"
}

#######################################
# Extract package name from APK filename
# APK format: {name}-{pkgver}[_{arch}]_{owrt_ver}.apk
# Strips the version suffix from the first _ segment (e.g., "gpio-fan-rpm-2.2.0-r2" → "gpio-fan-rpm")
# Arguments:
#   $1 - filename (basename only)
#######################################
extract_apk_package_name() {
    local filename="$1"
    local name_ver="${filename%%_*}"
    echo "$name_ver" | sed 's/-[0-9].*//'
}

#######################################
# Parse package type and metadata from filename
# Arguments:
#   $1 - filename (basename only)
# Outputs (one per line):
#   TYPE: all|regular|kmod
#   For all:     VERSION
#   For regular: ARCH, VERSION
#   For kmod:    ARCH, TARGET, SUBTARGET, VERSION (patch version)
#
# Where arch can contain underscores (e.g., x86_64, aarch64_cortex-a53)
# Kmods use patch version (e.g., 24.10.3), others use minor version (e.g., 24.10)
#######################################
parse_package_filename() {
    local filename="$1"
    local base="${filename%.ipk}"
    base="${base%.apk}"

    IFS='_' read -ra parts <<< "$base"
    local num_parts=${#parts[@]}

    if [[ $num_parts -lt 4 ]]; then
        log_warn "Too few parts in filename: $filename"
        return 1
    fi

    local openwrt_ver="${parts[$((num_parts-1))]}"

    # _all packages
    if [[ "$base" == *_all_* ]]; then
        if [[ ! "$openwrt_ver" =~ ^[0-9]+\.[0-9]+$ ]]; then
            log_warn "Invalid OpenWRT version in filename: $filename (got: $openwrt_ver)"
            return 1
        fi
        echo "all"
        echo "$openwrt_ver"
        return 0
    fi

    # kmod packages
    if [[ "$filename" == kmod-* ]]; then
        if [[ ! "$openwrt_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log_warn "Invalid OpenWRT patch version for kmod: $filename (got: $openwrt_ver, expected X.YY.Z)"
            return 1
        fi
        if [[ $num_parts -lt 5 ]]; then
            log_warn "Too few parts for kmod filename: $filename"
            return 1
        fi

        local target="${parts[1]}"
        local subtarget="${parts[2]}"
        local arch_parts=("${parts[@]:3:$((num_parts-4))}")
        local arch
        arch=$(IFS='_'; echo "${arch_parts[*]}")

        if [[ -z "$arch" || -z "$target" || -z "$subtarget" ]]; then
            log_warn "Failed to parse kmod filename: $filename"
            return 1
        fi
        echo "kmod"
        echo "$arch"
        echo "$target"
        echo "$subtarget"
        echo "$openwrt_ver"
        return 0
    fi

    # Regular packages
    if [[ ! "$openwrt_ver" =~ ^[0-9]+\.[0-9]+$ ]]; then
        log_warn "Invalid OpenWRT version in filename: $filename (got: $openwrt_ver)"
        return 1
    fi

    local arch_parts=("${parts[@]:2:$((num_parts-3))}")
    local arch
    arch=$(IFS='_'; echo "${arch_parts[*]}")

    if [[ -z "$arch" ]]; then
        log_warn "Failed to parse regular package filename: $filename"
        return 1
    fi
    echo "regular"
    echo "$arch"
    echo "$openwrt_ver"
}

#######################################
# Parse package type and metadata from an APK filename
# APK filename format differs from IPK: name and version are joined with "-"
# into a single "_"-delimited segment, so arch starts at index 1 (not 2).
#
# Formats:
#   arch-specific:     {name}-{pkgver}_{arch}_{owrt_ver}.apk
#   arch-independent:  {name}-{pkgver}_{owrt_ver}.apk   (only 2 "_" parts)
# Arguments:
#   $1 - filename (basename only)
# Outputs (one per line):
#   TYPE: all|regular
#   For all:     VERSION
#   For regular: ARCH, VERSION
#######################################
parse_apk_filename() {
    local filename="$1"
    local base="${filename%.apk}"

    IFS='_' read -ra parts <<< "$base"
    local num_parts=${#parts[@]}
    local openwrt_ver="${parts[$((num_parts-1))]}"

    if [[ ! "$openwrt_ver" =~ ^[0-9]+\.[0-9]+$ ]]; then
        log_warn "Invalid OpenWRT version in APK filename: $filename (got: $openwrt_ver)"
        return 1
    fi

    if [[ $num_parts -eq 2 ]]; then
        echo "all"
        echo "$openwrt_ver"
    elif [[ $num_parts -ge 3 ]]; then
        local arch_parts=("${parts[@]:1:$((num_parts-2))}")
        local arch
        arch=$(IFS='_'; echo "${arch_parts[*]}")
        echo "regular"
        echo "$arch"
        echo "$openwrt_ver"
    else
        log_warn "Invalid APK filename: $filename"
        return 1
    fi
}

#######################################
# Remove older versions of a package, keeping only the just-installed file
# Arguments:
#   $1 - directory path
#   $2 - package name
#   $3 - package extension (ipk or apk)
#   $4 - filename to keep
#######################################
cleanup_old_versions() {
    local dir="$1"
    local pkg_name="$2"
    local ext="${3:-ipk}"
    local keep_filename="$4"

    local pattern
    if [[ "$ext" == "apk" ]]; then
        pattern="${pkg_name}-*.${ext}"
    else
        pattern="${pkg_name}_*.${ext}"
    fi

    local packages=()
    while IFS= read -r -d '' pkg; do
        packages+=("$pkg")
    done < <(find "$dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)

    if [[ ${#packages[@]} -le 1 ]]; then
        return 0
    fi

    log_info "Cleaning up old versions of ${pkg_name} in ${dir}"
    for pkg in "${packages[@]}"; do
        if [[ "$(basename "$pkg")" != "$keep_filename" ]]; then
            log_info "  Removing old version: $(basename "$pkg")"
            rm -f "$pkg"
        fi
    done
}

#######################################
# Create directory with .gitkeep file
# Arguments:
#   $1 - directory path
#######################################
create_directory_with_gitkeep() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        touch "${dir}/.gitkeep"
        log_info "  Created new directory: ${dir#${REPO_ROOT}/}"
    fi
}

process_all_package() {
    local pkg_path="$1"
    local version="$2"
    local filename
    filename="$(basename "$pkg_path")"
    local ext="${filename##*.}"
    local pkg_name
    if [[ "$ext" == "apk" ]]; then
        pkg_name="$(extract_apk_package_name "$filename")"
    else
        pkg_name="$(extract_package_name "$filename")"
    fi

    log_info "Processing _all package: ${filename} (${version})"

    local target_dir="${REPO_ROOT}/${version}/all"
    create_directory_with_gitkeep "$target_dir"
    cp -f "$pkg_path" "${target_dir}/"
    cleanup_old_versions "$target_dir" "$pkg_name" "$ext" "$filename"
    log_info "  Installed to: ${target_dir#${REPO_ROOT}/}"
}

process_regular_package() {
    local pkg_path="$1"
    local arch="$2"
    local version="$3"
    local filename
    filename="$(basename "$pkg_path")"
    local ext="${filename##*.}"
    local pkg_name
    if [[ "$ext" == "apk" ]]; then
        pkg_name="$(extract_apk_package_name "$filename")"
    else
        pkg_name="$(extract_package_name "$filename")"
    fi

    log_info "Processing regular package: ${filename} (${arch}, ${version})"

    local target_dir="${REPO_ROOT}/${version}/packages/${arch}"
    create_directory_with_gitkeep "$target_dir"
    cp -f "$pkg_path" "${target_dir}/"
    cleanup_old_versions "$target_dir" "$pkg_name" "$ext" "$filename"
    log_info "  Installed to: ${target_dir#${REPO_ROOT}/}"
}

process_kmod_package() {
    local pkg_path="$1"
    local arch="$2"
    local target="$3"
    local subtarget="$4"
    local version="$5"
    local filename
    filename="$(basename "$pkg_path")"
    local ext="${filename##*.}"
    local pkg_name
    pkg_name="$(extract_package_name "$filename")"

    log_info "Processing kmod package: ${filename} (${arch}, ${target}/${subtarget}, ${version})"

    local target_dir="${REPO_ROOT}/kmods/${version}/${target}/${subtarget}"
    create_directory_with_gitkeep "$target_dir"
    cp -f "$pkg_path" "${target_dir}/"
    cleanup_old_versions "$target_dir" "$pkg_name" "$ext" "$filename"
    log_info "  Installed to: ${target_dir#${REPO_ROOT}/}"
}

main() {
    local incoming_dir="${1:-}"

    if [[ -z "$incoming_dir" || ! -d "$incoming_dir" ]]; then
        log_error "Usage: $0 <incoming_directory>"
        exit 1
    fi

    log_info "Starting package sync from: ${incoming_dir}"
    log_info "Repository root: ${REPO_ROOT}"

    local all_packages=()
    local regular_packages=()
    local kmod_packages=()

    for pkg in "${incoming_dir}"/*.ipk "${incoming_dir}"/*.apk; do
        [[ -f "$pkg" ]] || continue

        local filename
        filename="$(basename "$pkg")"

        local parse_output
        if [[ "$filename" == *.apk ]]; then
            if ! parse_output=$(parse_apk_filename "$filename"); then
                log_warn "Skipping unparseable APK package: ${filename}"
                continue
            fi
        else
            if ! parse_output=$(parse_package_filename "$filename"); then
                log_warn "Skipping unparseable IPK package: ${filename}"
                continue
            fi
        fi

        local type arch version target subtarget
        {
            read -r type
            case "$type" in
                all)
                    read -r version
                    all_packages+=("$pkg|$version")
                    log_info "Categorized as _all: ${filename} (${version})"
                    ;;
                regular)
                    read -r arch
                    read -r version
                    regular_packages+=("$pkg|$arch|$version")
                    log_info "Categorized as regular: ${filename} (${arch}, ${version})"
                    ;;
                kmod)
                    read -r arch
                    read -r target
                    read -r subtarget
                    read -r version
                    kmod_packages+=("$pkg|$arch|$target|$subtarget|$version")
                    log_info "Categorized as kmod: ${filename} (${arch}, ${target}/${subtarget}, ${version})"
                    ;;
            esac
        } <<< "$parse_output"
    done

    log_info ""
    log_info "=== Package Summary ==="
    log_info "  Regular packages: ${#regular_packages[@]}"
    log_info "  Kmod packages:    ${#kmod_packages[@]}"
    log_info "  _all packages:    ${#all_packages[@]}"
    log_info ""

    for entry in "${regular_packages[@]+"${regular_packages[@]}"}"; do
        IFS='|' read -r pkg arch version <<< "$entry"
        process_regular_package "$pkg" "$arch" "$version"
    done

    for entry in "${kmod_packages[@]+"${kmod_packages[@]}"}"; do
        IFS='|' read -r pkg arch target subtarget version <<< "$entry"
        process_kmod_package "$pkg" "$arch" "$target" "$subtarget" "$version"
    done

    for entry in "${all_packages[@]+"${all_packages[@]}"}"; do
        IFS='|' read -r pkg version <<< "$entry"
        process_all_package "$pkg" "$version"
    done

    log_info "Package sync complete"
}

main "$@"
