#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
variant="${1:-both}"
min_disk_kb=5242880

run_linux() {
	echo "VARIANT linux-core"
	if ! command -v swift >/dev/null 2>&1; then
		echo "RESULT fail-closed reason=no-swift"
		return 127
	fi
	echo "SWIFT $(swift --version 2>&1 | head -n 1)"
	(
		cd "$root/HolderCoreScratch"
		swift test
	)
}

run_preflight() {
	echo "VARIANT mac-preflight"
	local avail="${PROVE_DISK_AVAIL_KB:-}"
	if [[ -z "$avail" ]]; then
		avail="$(df -Pk / | awk 'NR==2 { print $4 }')"
	fi
	echo "DISK avail_kb=$avail floor_kb=$min_disk_kb"
	if [[ "$avail" -lt "$min_disk_kb" ]]; then
		echo "RESULT fail-closed reason=low-disk avail_kb=$avail"
		return 1
	fi
	if ! command -v xcodebuild >/dev/null 2>&1; then
		echo "RESULT fail-closed reason=no-xcodebuild"
		return 1
	fi
	if ! command -v xcrun >/dev/null 2>&1; then
		echo "RESULT fail-closed reason=no-xcrun"
		return 1
	fi
	echo "RESULT pass reason=apple-toolchain-present"
}

case "$variant" in
	linux)
		run_linux
		;;
	preflight)
		run_preflight
		;;
	both)
		set +e
		run_linux
		linux_status=$?
		echo
		run_preflight
		preflight_status=$?
		set -e
		echo
		echo "SUMMARY linux=$linux_status preflight=$preflight_status"
		if [[ "$linux_status" -ne 0 || "$preflight_status" -ne 0 ]]; then
			exit 1
		fi
		;;
	*)
		echo "usage: $0 linux|preflight|both" >&2
		exit 2
		;;
esac
