#!/usr/bin/env bash
#
# sync-packages.sh - Synchronize incoming packages to the OpenWRT feed
#
# Usage: sync-packages.sh <incoming_dir>
#
# This script:
# 1. Parses incoming .ipk files to determine their type and destination
# 2. Manages .master_all/ directory for architecture-independent packages
# 3. Distributes packages to appropriate version/arch directories
# 4. Removes older versions of packages (keeps only latest)
#

set -euo pipefail

# Enable extended globbing for pattern matching
shopt -s nullglob extglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MASTER_ALL_DIR="${REPO_ROOT}/.master_all"

# Logging functions
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

#######################################
# Extract package name from filename
# Handles various naming patterns
# Arguments:
#   $1 - filename (basename only)
# Returns:
#   Package name (everything before first _)
#######################################
extract_package_name() {
    local filename="$1"
    # Remove .ipk extension
    local base="${filename%.ipk}"
    # Package name is everything before first underscore
    echo "${base%%_*}"
}

#######################################
# Parse package type and metadata from filename
# Arguments:
#   $1 - filename (basename only)
# Outputs (one per line):
#   TYPE: all|regular|kmod
#   For all: no additional fields
#   For regular: ARCH, VERSION
#   For kmod: ARCH, TARGET, SUBTARGET, VERSION
#######################################
parse_package_filename() {
    local filename="$1"
    local base="${filename%.ipk}"

    # Type 1: _all packages (architecture independent)
    if [[ "$filename" == *_all.ipk ]]; then
        echo "all"
        return 0
    fi

    # Type 2: kmod packages
    # Pattern: kmod-{name}_{version}_{arch}_{target}_{subtarget}_{openwrt_ver}.ipk
    if [[ "$filename" == kmod-* ]]; then
        # Split by underscore from the end
        # Expected: kmod-name_ver_arch_target_subtarget_openwrt.ipk
        local openwrt_ver="${base##*_}"
        local rest="${base%_*}"
        local subtarget="${rest##*_}"
        rest="${rest%_*}"
        local target="${rest##*_}"
        rest="${rest%_*}"
        local arch="${rest##*_}"

        # Validate we got reasonable values
        if [[ -n "$arch" && -n "$target" && -n "$subtarget" && -n "$openwrt_ver" ]]; then
            echo "kmod"
            echo "$arch"
            echo "$target"
            echo "$subtarget"
            echo "$openwrt_ver"
            return 0
        else
            log_warn "Failed to parse kmod filename: $filename"
            return 1
        fi
    fi

    # Type 3: Regular packages
    # Pattern: {name}_{version}_{arch}_{openwrt_ver}.ipk
    # Split from end to get version and arch
    local openwrt_ver="${base##*_}"
    local rest="${base%_*}"
    local arch="${rest##*_}"

    if [[ -n "$arch" && -n "$openwrt_ver" ]]; then
        echo "regular"
        echo "$arch"
        echo "$openwrt_ver"
        return 0
    else
        log_warn "Failed to parse regular package filename: $filename"
        return 1
    fi
}

#######################################
# Get all existing package directories (not kmods)
# Arguments:
#   None
# Outputs:
#   List of [version]/packages/[arch] directories
#######################################
get_all_package_dirs() {
    local version_dirs
    version_dirs=$(find "${REPO_ROOT}" -maxdepth 1 -type d -regex '.*/[0-9]+\.[0-9]+' 2>/dev/null)

    for version_dir in $version_dirs; do
        local packages_dir="${version_dir}/packages"
        if [[ -d "$packages_dir" ]]; then
            find "$packages_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
        fi
    done
}

#######################################
# Remove older versions of a package from a directory
# Keeps only the newest version (by modification time)
# Arguments:
#   $1 - directory path
#   $2 - package name
#######################################
cleanup_old_versions() {
    local dir="$1"
    local pkg_name="$2"

    # Find all versions of this package
    local packages=()
    while IFS= read -r -d '' pkg; do
        packages+=("$pkg")
    done < <(find "$dir" -maxdepth 1 -name "${pkg_name}_*.ipk" -print0 2>/dev/null)

    if [[ ${#packages[@]} -le 1 ]]; then
        return 0
    fi

    log_info "Cleaning up old versions of ${pkg_name} in ${dir}"

    # Sort by modification time, keep newest
    local newest
    newest=$(ls -t "${packages[@]}" 2>/dev/null | head -1)

    for pkg in "${packages[@]}"; do
        if [[ "$pkg" != "$newest" ]]; then
            log_info "  Removing old version: $(basename "$pkg")"
            rm -f "$pkg"
        fi
    done
}

#######################################
# Process an _all package
# - Update .master_all directory
# - Copy to ALL existing package directories
# Arguments:
#   $1 - path to package file
#######################################
process_all_package() {
    local pkg_path="$1"
    local filename
    filename="$(basename "$pkg_path")"
    local pkg_name
    pkg_name="$(extract_package_name "$filename")"

    log_info "Processing _all package: ${filename}"

    # Ensure master_all directory exists
    mkdir -p "${MASTER_ALL_DIR}"

    # Remove older versions from master_all
    cleanup_old_versions "${MASTER_ALL_DIR}" "$pkg_name"

    # Copy to master_all
    cp -f "$pkg_path" "${MASTER_ALL_DIR}/"
    log_info "  Added to .master_all/"

    # Copy to all existing package directories
    while IFS= read -r pkg_dir; do
        if [[ -d "$pkg_dir" ]]; then
            cleanup_old_versions "$pkg_dir" "$pkg_name"
            cp -f "$pkg_path" "${pkg_dir}/"
            log_info "  Distributed to: ${pkg_dir#${REPO_ROOT}/}"
        fi
    done < <(get_all_package_dirs)
}

#######################################
# Process a regular package
# - Create target directory if needed
# - Copy .master_all packages to new directories
# - Move package to target
# Arguments:
#   $1 - path to package file
#   $2 - architecture (e.g., aarch64_cortex-a53)
#   $3 - OpenWRT version (e.g., 23.05)
#######################################
process_regular_package() {
    local pkg_path="$1"
    local arch="$2"
    local version="$3"
    local filename
    filename="$(basename "$pkg_path")"
    local pkg_name
    pkg_name="$(extract_package_name "$filename")"

    log_info "Processing regular package: ${filename}"
    log_info "  Arch: ${arch}, Version: ${version}"

    local target_dir="${REPO_ROOT}/${version}/packages/${arch}"
    local is_new_dir=false

    # Create directory if needed
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
        is_new_dir=true
        log_info "  Created new directory: ${target_dir#${REPO_ROOT}/}"
    fi

    # If new directory, copy all master_all packages
    if [[ "$is_new_dir" == true && -d "${MASTER_ALL_DIR}" ]]; then
        log_info "  Copying .master_all packages to new directory"
        for master_pkg in "${MASTER_ALL_DIR}"/*.ipk; do
            if [[ -f "$master_pkg" ]]; then
                cp -f "$master_pkg" "${target_dir}/"
                log_info "    Copied: $(basename "$master_pkg")"
            fi
        done
    fi

    # Remove older versions of this package
    cleanup_old_versions "$target_dir" "$pkg_name"

    # Copy package to target
    cp -f "$pkg_path" "${target_dir}/"
    log_info "  Installed to: ${target_dir#${REPO_ROOT}/}"
}

#######################################
# Process a kmod package
# - Create target directory if needed
# - Move package to target
# Arguments:
#   $1 - path to package file
#   $2 - architecture
#   $3 - target (e.g., mediatek)
#   $4 - subtarget (e.g., filogic)
#   $5 - OpenWRT version
#######################################
process_kmod_package() {
    local pkg_path="$1"
    local arch="$2"
    local target="$3"
    local subtarget="$4"
    local version="$5"
    local filename
    filename="$(basename "$pkg_path")"
    local pkg_name
    pkg_name="$(extract_package_name "$filename")"

    log_info "Processing kmod package: ${filename}"
    log_info "  Arch: ${arch}, Target: ${target}/${subtarget}, Version: ${version}"

    local target_dir="${REPO_ROOT}/${version}/kmods/${target}/${subtarget}"

    # Create directory if needed
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
        log_info "  Created new directory: ${target_dir#${REPO_ROOT}/}"
    fi

    # Remove older versions of this package
    cleanup_old_versions "$target_dir" "$pkg_name"

    # Copy package to target
    cp -f "$pkg_path" "${target_dir}/"
    log_info "  Installed to: ${target_dir#${REPO_ROOT}/}"
}

#######################################
# Sync all .master_all packages to existing directories
# Called after processing all packages to ensure consistency
#######################################
sync_master_all_to_all_dirs() {
    if [[ ! -d "${MASTER_ALL_DIR}" ]]; then
        return 0
    fi

    local master_pkgs=("${MASTER_ALL_DIR}"/*.ipk)
    if [[ ${#master_pkgs[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Final sync: ensuring .master_all packages in all directories"

    while IFS= read -r pkg_dir; do
        if [[ -d "$pkg_dir" ]]; then
            for master_pkg in "${master_pkgs[@]}"; do
                if [[ -f "$master_pkg" ]]; then
                    local master_name
                    master_name="$(extract_package_name "$(basename "$master_pkg")")"
                    cleanup_old_versions "$pkg_dir" "$master_name"
                    cp -f "$master_pkg" "${pkg_dir}/"
                fi
            done
        fi
    done < <(get_all_package_dirs)
}

#######################################
# Main entry point
#######################################
main() {
    local incoming_dir="${1:-}"

    if [[ -z "$incoming_dir" || ! -d "$incoming_dir" ]]; then
        log_error "Usage: $0 <incoming_directory>"
        exit 1
    fi

    log_info "Starting package sync from: ${incoming_dir}"
    log_info "Repository root: ${REPO_ROOT}"

    # Collect all incoming packages by type
    local all_packages=()
    local regular_packages=()
    local kmod_packages=()

    # First pass: categorize packages
    for pkg in "${incoming_dir}"/*.ipk; do
        if [[ ! -f "$pkg" ]]; then
            continue
        fi

        local filename
        filename="$(basename "$pkg")"

        # Parse the package
        local parse_output
        if ! parse_output=$(parse_package_filename "$filename"); then
            log_warn "Skipping unparseable package: ${filename}"
            continue
        fi

        # Read parsed output
        local type arch version target subtarget
        {
            read -r type
            case "$type" in
                all)
                    all_packages+=("$pkg")
                    log_info "Categorized as _all: ${filename}"
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
    log_info "  Kmod packages: ${#kmod_packages[@]}"
    log_info "  _all packages: ${#all_packages[@]}"
    log_info ""

    # Process regular packages first (may create new directories)
    if [[ ${#regular_packages[@]} -gt 0 ]]; then
        log_info "=== Processing ${#regular_packages[@]} regular package(s) ==="
        for entry in "${regular_packages[@]}"; do
            IFS='|' read -r pkg arch version <<< "$entry"
            process_regular_package "$pkg" "$arch" "$version"
        done
        log_info ""
    fi

    # Process kmod packages
    if [[ ${#kmod_packages[@]} -gt 0 ]]; then
        log_info "=== Processing ${#kmod_packages[@]} kmod package(s) ==="
        for entry in "${kmod_packages[@]}"; do
            IFS='|' read -r pkg arch target subtarget version <<< "$entry"
            process_kmod_package "$pkg" "$arch" "$target" "$subtarget" "$version"
        done
        log_info ""
    fi

    # Process _all packages (after regular packages so new dirs exist)
    if [[ ${#all_packages[@]} -gt 0 ]]; then
        log_info "=== Processing ${#all_packages[@]} _all package(s) ==="
        for pkg in "${all_packages[@]}"; do
            process_all_package "$pkg"
        done
        log_info ""
    fi

    # Final sync of master_all to catch any edge cases
    sync_master_all_to_all_dirs

    log_info "Package sync complete"
}

main "$@"
