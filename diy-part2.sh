#!/bin/bash
#
# diy-part2.sh — OpenWrt DIY script part 2 (after feeds install).
# Runs inside the OpenWrt tree (openwrt-25.12 / apk).
#
# 1. Clone the third-party package repos at HEAD ("upstream-update" in
#    update-checker.yml watches the same HEADs; they are recorded in
#    ../repo-heads.txt and shipped in the release notes).
# 2. Materialize package/podkop-engine from podkop-net/podkop-engine: the repo
#    ships only the package skeleton (openwrt/podkop-engine) plus the patch set
#    per sing-box line, so version.mk is generated here exactly like their
#    scripts/sdk-build.sh does it for the SDK. The clone itself is removed
#    afterwards so the package scanner never walks it.
#    NOTE: podkop-engine replaces stock sing-box — stock sing-box has no XHTTP
#    transport, which the providers need.
# 3. Mode safety net: strip group/other write (rpcd skips world-writable ucode
#    plugins), keep uci-defaults and libexec workers executable. Git clones
#    normally carry proper bits — this guards against regressions (e.g. a repo
#    committed from Windows).
# 4. Enforce the include/scan.mk marker: a Makefile without the literal
#    "call BuildPackage" (or "call KernelPackage" for kmod packages) is
#    SILENTLY skipped by the package scanner, the build still succeeds and the
#    image silently lacks the package.

set -eu

# sing-box line of podkop-engine (patches/v<line> in their repo).
PODKOP_ENGINE_LINE="${PODKOP_ENGINE_LINE:-1.14}"

cd package

clone() {
	[ -d "$1" ] || git clone --depth 1 "$2" "$1"
}

clone zapret2-openwrt   https://github.com/1andrevich/zapret2-openwrt
clone awg-openwrt       https://github.com/slava-shchipunov/awg-openwrt
clone podkop            https://github.com/itdoginfo/podkop
clone luci-theme-argon  https://github.com/jerrykuku/luci-theme-argon
clone podkop-engine-src https://github.com/podkop-net/podkop-engine

CLONED="zapret2-openwrt awg-openwrt podkop luci-theme-argon podkop-engine-src"

# Repo HEADs for the release notes.
: > ../repo-heads.txt
for d in $CLONED; do
	printf '%s %s\n' "$d" "$(git -C "$d" rev-parse HEAD)" >> ../repo-heads.txt
done

# --- podkop-engine: skeleton + patches + version.mk -----------------------
. podkop-engine-src/versions.env

key=$(printf '%s' "$PODKOP_ENGINE_LINE" | tr . _)
eval "SB_VERSION=\${SB_${key}_VERSION:-}"
eval "SB_HASH=\${SB_${key}_HASH:-}"
eval "SB_RELEASE=\${SB_${key}_RELEASE:-}"

[ -n "$SB_VERSION" ] && [ -n "$SB_HASH" ] && [ -n "$SB_RELEASE" ] || {
	echo "ERROR: podkop-engine line $PODKOP_ENGINE_LINE is not defined in versions.env" >&2
	exit 1
}
[ -d "podkop-engine-src/patches/v$PODKOP_ENGINE_LINE" ] || {
	echo "ERROR: podkop-engine has no patches/v$PODKOP_ENGINE_LINE (bump PODKOP_ENGINE_LINE)" >&2
	exit 1
}

rm -rf podkop-engine
cp -a podkop-engine-src/openwrt/podkop-engine podkop-engine
mkdir -p podkop-engine/patches
cp "podkop-engine-src/patches/v$PODKOP_ENGINE_LINE"/*.patch podkop-engine/patches/
cat > podkop-engine/version.mk <<EOF
SB_VERSION:=$SB_VERSION
SB_HASH:=$SB_HASH
SB_RELEASE:=$SB_RELEASE
EOF
printf 'podkop-engine %s-r%s (patches v%s, fork %s)\n' \
	"$SB_VERSION" "$SB_RELEASE" "$PODKOP_ENGINE_LINE" \
	"$(git -C podkop-engine-src rev-parse HEAD)" | tee -a ../repo-heads.txt

rm -rf podkop-engine-src
CLONED="zapret2-openwrt awg-openwrt podkop luci-theme-argon podkop-engine"

cd ..

# --- mode safety net ------------------------------------------------------
for d in $CLONED; do
	find "package/$d" -type f -perm /022 -exec chmod go-w {} +
done
find package -path '*/etc/uci-defaults/*' -type f -exec chmod 0755 {} +
find package -path '*/usr/libexec/*' -type f -exec chmod 0755 {} +

# --- scan.mk marker check -------------------------------------------------
# Regular packages end with "call BuildPackage"; kernel modules use
# "call KernelPackage" and would otherwise be reported as missing.
for m in package/zapret2-openwrt/zapret2/Makefile \
         package/zapret2-openwrt/luci-app-zapret2/Makefile \
         package/awg-openwrt/kmod-amneziawg/Makefile \
         package/awg-openwrt/amneziawg-tools/Makefile \
         package/awg-openwrt/luci-proto-amneziawg/Makefile \
         package/podkop/podkop/Makefile \
         package/podkop/luci-app-podkop/Makefile \
         package/luci-theme-argon/Makefile \
         package/podkop-engine/Makefile; do
	grep -Eq 'call (BuildPackage|KernelPackage)' "$m" || { echo "ERROR: scan.mk marker missing in $m" >&2; exit 1; }
done

echo "diy-part2 OK"