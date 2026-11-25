#!/bin/bash
#
# diy-part1.sh — OpenWrt DIY script part 1 (before feeds update).
# Runs inside the OpenWrt tree.
#
# 1. Drop feeds nothing in the composition uses: telephony and video (the
#    video feed's qt5/qt6 Config.in also produces Kconfig recursive-dependency
#    noise). routing stays — it is cheap and the feeds.conf is pinned to the
#    release branch.
# 2. Switch git.openwrt.org feed URLs to GitHub mirrors, PRESERVING the
#    ";branch" suffix (the openwrt-25.12 tree pins feeds to ;openwrt-25.12 —
#    dropping the suffix would silently track the default branch instead).
# 3. No extra feeds: zapret2, podkop, podkop-engine, amneziawg and the Argon
#    theme are cloned as packages in diy-part2.sh.

set -e

sed -i '/^src-git telephony /d; /^src-git video /d' feeds.conf.default

sed -i 's|https://git.openwrt.org/feed/packages.git|https://github.com/openwrt/packages.git|' feeds.conf.default
sed -i 's|https://git.openwrt.org/project/luci.git|https://github.com/openwrt/luci.git|' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/routing.git|https://github.com/openwrt/routing.git|' feeds.conf.default

cat feeds.conf.default