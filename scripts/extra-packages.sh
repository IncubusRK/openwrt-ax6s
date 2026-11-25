#!/bin/sh
# extra-packages.sh — build an archive of ONLY the packages NOT included in the
# firmware image.
#
# Usage:
#   scripts/extra-packages.sh <manifest> <packages-dir> <out.tar.gz>
#     manifest      — bin/targets/.../openwrt-*.manifest
#     packages-dir  — bin/packages (searched recursively for *.apk / *.ipk)
#     out.tar.gz    — resulting archive
#
# Why: kmod packages are tied to the exact kernel of the release, so "install it
# later from the feed" is not an option on OpenWrt. Everything optional must
# come from the same build — hence the archive of the packages that were built
# but not baked into the image.
#
# Logic: image composition = names+versions from the manifest. A package file is
# "name-version[.arch].apk". A file whose name-version (with or without the
# architecture suffix stripped) is in the manifest is part of the image; all
# others are copied to staging and packed (flat layout).

set -eu

MANIFEST="${1:?usage: extra-packages.sh <manifest> <packages-dir> <out.tar.gz>}"
PKGDIR="${2:?usage: extra-packages.sh <manifest> <packages-dir> <out.tar.gz>}"
OUT="${3:?usage: extra-packages.sh <manifest> <packages-dir> <out.tar.gz>}"

[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST" >&2; exit 1; }
[ -d "$PKGDIR" ] || { echo "packages dir not found: $PKGDIR" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Image composition keys "name-version". Handles both manifest formats:
#   opkg: "name - version"                -> "name-version"
#   apk:  "name-version arch description" -> "name-version"
awk '
	NF && $1 !~ /^#/ {
		if ($2 == "-") print $1 "-" $3
		else           print $1
	}' "$MANIFEST" | sort -u > "$STAGE/image.keys"

find "$PKGDIR" \( -name '*.apk' -o -name '*.ipk' \) -type f | sort | while read -r f; do
	base="$(basename "$f")"
	case "$base" in
	*.apk)
		# apk: "<name>-<version>[.<arch>].apk"
		key="${base%.apk}"
		;;
	*.ipk)
		# opkg/ipk: "<name>_<version>_<arch>.ipk"
		base="${base%.ipk}"
		name="${base%%_*}"
		rest="${base#*_}"
		key="$name-${rest%%_*}"
		;;
	esac
	grep -qxF "$key" "$STAGE/image.keys" && continue
	# strip the architecture suffix (last ".segment"), if present
	trimmed="${key%.*}"
	if [ "$trimmed" != "$key" ] && grep -qxF "$trimmed" "$STAGE/image.keys"; then
		continue
	fi
	cp "$f" "$STAGE/"
done

COUNT="$(find "$STAGE" \( -name '*.apk' -o -name '*.ipk' \) | wc -l)"
echo "extra packages: $COUNT"
if [ "$COUNT" -eq 0 ]; then
	echo "warning: no extra packages found" >&2
fi

# image.keys is a staging helper, not a package — do not ship it
rm -f "$STAGE/image.keys"
tar -czf "$OUT" -C "$STAGE" .
echo "archive: $OUT ($(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT") bytes)"