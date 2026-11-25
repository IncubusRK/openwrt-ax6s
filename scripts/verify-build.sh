#!/bin/bash
# verify-build.sh — post-build manifest verification.
#
# Usage: scripts/verify-build.sh <manifest>
#
# The build fails loudly if a package silently dropped out of the image. This
# matters because the third-party packages are cloned at HEAD: an upstream
# rename or a broken Makefile otherwise yields a "successful" build without the
# proxy stack.
#
# Manifest formats differ between opkg and apk builds:
#   opkg:  "name - version"
#   apk:   "name-version arch description" (OpenWrt seds the first space to " - ")
# so normalize every line to a bare package name first.
#
# The image size guard lives in the workflow (it knows the target dir).

set -u

MAN="${1:?usage: verify-build.sh <manifest>}"
[ -f "$MAN" ] || { echo "manifest not found: $MAN" >&2; exit 1; }

fail=0

NAMES=$(awk 'NF && $1 !~ /^#/ { n = $1; sub(/-[0-9].*$/, "", n); print n }' "$MAN" | sort -u)

have() {
	printf '%s\n' "$NAMES" | grep -qxF -- "$1" || { echo "MISSING: $1"; fail=1; }
}
have_any() {
	for p in "$@"; do
		if printf '%s\n' "$NAMES" | grep -qxF -- "$p"; then return 0; fi
	done
	echo "MISSING (any of): $*"
	fail=1
}
absent() {
	if printf '%s\n' "$NAMES" | grep -qxF -- "$1"; then echo "UNWANTED: $1"; fail=1; fi
}

# --- must be in the image -------------------------------------------------
for p in zapret2 luci-app-zapret2 \
         podkop luci-app-podkop podkop-engine \
         kmod-amneziawg amneziawg-tools luci-proto-amneziawg \
         wireguard-tools luci-proto-wireguard \
         luci-theme-argon \
         sqm-scripts luci-app-sqm kmod-sched-cake \
         nlbwmon luci-app-nlbwmon watchcat luci-app-watchcat \
         luci-app-attendedsysupgrade kmod-tcp-bbr wpad-mbedtls \
         dnsmasq-full curl iperf3 tcpdump; do
	have "$p"
done
have_any mtr mtr-json

# Translations are cosmetic: report, do not fail the build over them.
for p in luci-i18n-base-ru luci-i18n-firewall-ru luci-i18n-argon-config-ru; do
	if ! printf '%s\n' "$NAMES" | grep -qxF -- "$p"; then
		echo "WARN: $p missing (cosmetic)"
	fi
done

# --- must stay out of the image ------------------------------------------
# python3/ruantiblock: replaced by zapret2 (no python stack on a 128 MiB NAND)
# zapret/ipset/iptables-*: the old remittor stack
# sing-box: replaced by podkop-engine (stock sing-box has no XHTTP)
# luci-app-argon-config: settings live inside luci-theme-argon since 3.0
# luci-ssl-openssl: podkop's dashboard (Clash API) needs plain HTTP
# NB: iptables + iptables-mod-ipopt are pulled by sqm-scripts (packet marking)
# and are expected; only the DPI-era pieces are forbidden.
for p in python3 libpython3 ruantiblock luci-app-ruantiblock \
         zapret luci-app-zapret ipset iptables-mod-nfqueue \
         sing-box sing-box-tiny podkop-engine-full \
         luci-app-argon-config luci-ssl-openssl \
         adguardhome docker dockerd luci-app-openclash \
         v2raya xray-core openvpn-mbedtls xl2tpd \
         screen htop; do
	absent "$p"
done

if [ "$fail" -eq 0 ]; then
	echo "VERIFY OK"
else
	echo "VERIFY FAILED" >&2
	exit 1
fi