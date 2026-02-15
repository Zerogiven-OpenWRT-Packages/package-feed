#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="${1:-.}"
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"

# Find all Packages index files and process them with awk
find "$REPO_ROOT" -name "Packages" -not -path "*/.git/*" -type f -print0 | \
xargs -0 awk -v repo_root="$REPO_ROOT" '
# Derive OpenWRT minor version from file path
function derive_version(filepath,    rel, parts, n, patch) {
    rel = filepath
    sub(repo_root "/", "", rel)
    if (rel ~ /^kmods\//) {
        # kmods/<patch_version>/... → strip to minor version
        n = split(rel, parts, "/")
        patch = parts[2]
        # Remove last .N from patch version (24.10.3 → 24.10)
        sub(/\.[0-9]+$/, "", patch)
        return patch
    } else {
        # <version>/... → first path component
        n = split(rel, parts, "/")
        return parts[1]
    }
}

# Simplify architecture string
function simplify_arch(arch) {
    if (arch == "all") return "all"
    if (arch == "x86_64") return "x86_64"
    # Take everything before first underscore
    sub(/_.*/, "", arch)
    return arch
}

# Track when we switch to a new file
FILENAME != prev_file {
    openwrt_ver = derive_version(FILENAME)
    prev_file = FILENAME
}

# Parse fields from each entry
/^Package: /  { name = substr($0, 10) }
/^Version: /  { version = substr($0, 10) }
/^Architecture: / { arch = substr($0, 15) }
/^URL: /      { url = substr($0, 6) }
/^Description: /  {
    desc = substr($0, 14)
    # Trim leading whitespace
    sub(/^[[:space:]]+/, "", desc)
}

# Blank line = end of entry
/^$/ {
    if (name != "" && name !~ /^luci-i18n-/) {
        sa = simplify_arch(arch)

        # Store data (latest wins, which is fine)
        descriptions[name] = desc
        versions[name] = version
        urls[name] = url

        # Collect unique OpenWRT versions
        key = name SUBSEP openwrt_ver
        if (!(key in seen_ver)) {
            seen_ver[key] = 1
            if (name in openwrt_versions)
                openwrt_versions[name] = openwrt_versions[name] " " openwrt_ver
            else
                openwrt_versions[name] = openwrt_ver
        }

        # Collect unique architectures
        key = name SUBSEP sa
        if (!(key in seen_arch)) {
            seen_arch[key] = 1
            if (name in archs)
                archs[name] = archs[name] " " sa
            else
                archs[name] = sa
        }
    }
    name = ""; version = ""; arch = ""; desc = ""; url = ""
}

END {
    # Handle last entry if file does not end with blank line
    if (name != "" && name !~ /^luci-i18n-/) {
        sa = simplify_arch(arch)
        descriptions[name] = desc
        versions[name] = version
        urls[name] = url

        key = name SUBSEP openwrt_ver
        if (!(key in seen_ver)) {
            seen_ver[key] = 1
            if (name in openwrt_versions)
                openwrt_versions[name] = openwrt_versions[name] " " openwrt_ver
            else
                openwrt_versions[name] = openwrt_ver
        }

        key = name SUBSEP sa
        if (!(key in seen_arch)) {
            seen_arch[key] = 1
            if (name in archs)
                archs[name] = archs[name] " " sa
            else
                archs[name] = sa
        }
    }

    # Collect and sort package names
    n = 0
    for (name in descriptions) {
        names[++n] = name
    }

    # Simple insertion sort (portable)
    for (i = 2; i <= n; i++) {
        tmp = names[i]
        j = i - 1
        while (j >= 1 && names[j] > tmp) {
            names[j+1] = names[j]
            j--
        }
        names[j+1] = tmp
    }

    # Output table header
    print "| Package | Description | Version | OpenWRT | Arch |"
    print "|---------|-------------|---------|---------|------|"

    for (i = 1; i <= n; i++) {
        name = names[i]
        d = descriptions[name]

        # Truncate long descriptions
        if (length(d) > 80) d = substr(d, 1, 77) "..."

        # Format package name as markdown link if URL available
        if (name in urls && urls[name] != "")
            pkg_display = "[" name "](" urls[name] ")"
        else
            pkg_display = name

        # Sort version list
        nv = split(openwrt_versions[name], varr, " ")
        for (vi = 2; vi <= nv; vi++) {
            vtmp = varr[vi]
            vj = vi - 1
            while (vj >= 1 && varr[vj] > vtmp) {
                varr[vj+1] = varr[vj]
                vj--
            }
            varr[vj+1] = vtmp
        }
        ver_list = varr[1]
        for (vi = 2; vi <= nv; vi++) ver_list = ver_list ", " varr[vi]

        # Sort arch list
        na = split(archs[name], aarr, " ")
        for (ai = 2; ai <= na; ai++) {
            atmp = aarr[ai]
            aj = ai - 1
            while (aj >= 1 && aarr[aj] > atmp) {
                aarr[aj+1] = aarr[aj]
                aj--
            }
            aarr[aj+1] = atmp
        }
        arch_list = aarr[1]
        for (ai = 2; ai <= na; ai++) arch_list = arch_list ", " aarr[ai]

        printf "| %s | %s | %s | %s | %s |\n", \
            pkg_display, d, versions[name], ver_list, arch_list
    }
}
'
