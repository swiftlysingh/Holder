#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

run_linux() {
	echo "VARIANT linux-core"
	if ! command -v swift >/dev/null 2>&1; then
		echo "RESULT fail-closed reason=no-swift"
		return 127
	fi
	echo "SWIFT $(swift --version 2>&1 | head -n 1)"
	(
		cd "$root"
		swift test
	)
}

case "${1:-}" in
	linux)
		run_linux
		;;
	*)
		echo "usage: $0 linux" >&2
		exit 2
		;;
esac
