#!/usr/bin/env bash
set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(git -C "$skill_dir" rev-parse --show-toplevel)"
state_root="${HOLDER_VERIFY_ROOT:-${TMPDIR:-/tmp}/holder-verify}"
evidence_root="${HOLDER_VERIFY_EVIDENCE:-$state_root/evidence}"
toolchain="${HOLDER_SWIFT_TOOLCHAIN:-/tmp/swift-toolchain}"
swift_release="swift-6.2.1-RELEASE"
swift_url="https://download.swift.org/swift-6.2.1-release/ubuntu2404/$swift_release/$swift_release-ubuntu24.04.tar.gz"

compiled_sources=(
	cards/ScanView/CardCandidateEngine.swift
	cards/ScanView/CardScanSession.swift
	cards/Model/CardData.swift
)
extracted_sources=(
	cards/ScanView/CardScanning.swift
	cards/Extensions.swift
)
driver_source="$skill_dir/scripts/holder-scan/main.swift"

glue_checks=(
	"cards/ScanView/VisionCardScanningEngine.swift|private var voter = TemporalPANVoter()"
	"cards/ScanView/VisionCardScanningEngine.swift|let observation = CardCandidateEngine.observe(items)"
	"cards/ScanView/VisionCardScanningEngine.swift|attempt.record(observation)"
	"cards/ScanView/VisionCardScanningEngine.swift|guard let winner = voter.record(pan) else { return }"
	"cards/ScanView/VisionCardScanningEngine.swift|guard still.pan == nil || still.pan == livePAN else { return nil }"
	"cards/ScanView/VisionCardScanningEngine.swift|expiry: still.expiry ?? attempt.latestObservation.expiry,"
	"cards/ScanView/VisionCardScanningEngine.swift|cardholderName: still.cardholderName,"
	"cards/ScanView/VisionCardScanningEngine.swift|expiry: attempt.latestObservation.expiry,"
	"cards/ScanView/VisionCardScanningEngine.swift|return CardCandidateEngine.observe(items)"
	"cards/CardView/CardViewModel.swift|CardScanSession.apply(result, to: &card)"
)

if [[ -x "$toolchain/usr/bin/swift" ]]; then
	PATH="$toolchain/usr/bin:$PATH"
fi

fail_closed() {
	echo "RESULT fail-closed surface=$1 reason=$2"
	exit "${3:-1}"
}

swift_version() {
	command -v swift >/dev/null 2>&1 && swift --version 2>/dev/null | head -n 1
}

require_run() {
	run_id="${HOLDER_VERIFY_RUN_ID:-}"
	[[ -n "$run_id" ]] || fail_closed core no-run-id 2
	[[ "$run_id" =~ ^[A-Za-z0-9._-]+$ ]] || fail_closed core bad-run-id 2
	run_dir="$state_root/runs/$run_id"
	binary="$run_dir/build/debug/holder-scan"
}

sources_fresh() {
	[[ -f "$run_dir/sources.sha256" ]] && sha256sum --check --quiet --status "$run_dir/sources.sha256"
}

extract_decl() {
	awk -v pattern="$2" '$0 ~ pattern { p = 1 } p { print } p && /^}/ { p = 0 }' "$repo_root/$1"
}

cmd_setup_swift() {
	if swift_version >/dev/null; then
		echo "SWIFT $(swift_version)"
		echo "RESULT ready surface=toolchain"
		return
	fi
	[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail_closed toolchain unsupported-host
	grep -q '^VERSION_ID="24.04"' /etc/os-release || fail_closed toolchain not-ubuntu-24.04
	if ! ldconfig -p | grep -q 'libncurses.so.6'; then
		sudo apt-get update -qq
		sudo apt-get install -y -qq libncurses6
	fi
	local archive
	archive="$(mktemp --suffix=.tar.gz)"
	curl -fSL --retry 3 -o "$archive" "$swift_url"
	mkdir -p "$toolchain"
	tar -xzf "$archive" -C "$toolchain" --strip-components=1
	rm -f "$archive"
	PATH="$toolchain/usr/bin:$PATH"
	swift_version >/dev/null || fail_closed toolchain swift-does-not-run
	echo "SWIFT $(swift_version)"
	echo "RESULT ready surface=toolchain path=$toolchain/usr/bin"
}

cmd_launch() {
	swift_version >/dev/null || { echo "HINT run: $0 setup-swift"; fail_closed core no-swift 127; }
	export HOLDER_VERIFY_RUN_ID="${HOLDER_VERIFY_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
	require_run
	local pkg="$run_dir/pkg"
	local target="$pkg/Sources/holder-scan"
	mkdir -p "$pkg/Sources/CoreGraphics" "$target"

	cat >"$pkg/Package.swift" <<-'EOF'
	// swift-tools-version: 5.9
	import PackageDescription

	let package = Package(
		name: "HolderVerify",
		targets: [
			.target(name: "CoreGraphics"),
			.executableTarget(
				name: "holder-scan",
				dependencies: ["CoreGraphics"],
				swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
			),
		]
	)
	EOF
	echo '@_exported import Foundation' >"$pkg/Sources/CoreGraphics/Shim.swift"

	local source
	for source in "${compiled_sources[@]}"; do
		ln -sfn "$repo_root/$source" "$target/$(basename "$source")"
	done
	ln -sfn "$driver_source" "$target/main.swift"

	local scan_result string_ext uint_ext
	scan_result="$(extract_decl cards/ScanView/CardScanning.swift '^struct CardScanResult[: ]')"
	string_ext="$(extract_decl cards/Extensions.swift '^extension String [{]')"
	uint_ext="$(extract_decl cards/Extensions.swift '^extension UInt [{]')"
	[[ -n "$scan_result" ]] || fail_closed core extract-failed-CardScanResult
	[[ -n "$string_ext" ]] || fail_closed core extract-failed-String-extension
	[[ -n "$uint_ext" ]] || fail_closed core extract-failed-UInt-extension
	printf 'import Foundation\n\n%s\n\n%s\n\n%s\n' "$scan_result" "$string_ext" "$uint_ext" >"$target/Extracted.swift"

	sha256sum "${compiled_sources[@]/#/$repo_root/}" "${extracted_sources[@]/#/$repo_root/}" "$driver_source" >"$run_dir/sources.sha256"
	{
		echo "head=$(git -C "$repo_root" rev-parse HEAD)"
		echo "dirty_cards=$(git -C "$repo_root" status --porcelain -- cards | wc -l | tr -d ' ')"
		echo "swift=$(swift_version)"
	} >"$run_dir/provenance.txt"

	if ! swift build --package-path "$pkg" --scratch-path "$run_dir/build" >"$run_dir/build.log" 2>&1; then
		tail -n 30 "$run_dir/build.log"
		fail_closed core build-failed
	fi
	"$binary" --ready
	echo "export HOLDER_VERIFY_RUN_ID=$run_id"
	echo "RESULT ready surface=core run=$run_id dir=$run_dir"
}

app_preflight() {
	if [[ "$(uname -s)" != Darwin ]]; then
		echo "RESULT fail-closed surface=app reason=not-macos host=$(uname -s)"
		return 1
	fi
	if ! command -v xcodebuild >/dev/null 2>&1; then
		echo "RESULT fail-closed surface=app reason=no-xcodebuild"
		return 1
	fi
	if ! xcrun simctl help >/dev/null 2>&1; then
		echo "RESULT fail-closed surface=app reason=no-simctl"
		return 1
	fi
	echo "RESULT ready surface=app xcode=\"$(xcodebuild -version | head -n 1)\""
}

cmd_doctor() {
	local status=0 core="ok" app="ok" check file needle
	echo "DOCTOR repo=$repo_root head=$(git -C "$repo_root" rev-parse --short HEAD)"
	if swift_version >/dev/null; then
		echo "CORE swift=\"$(swift_version)\""
	else
		echo "CORE swift=missing hint=\"$0 setup-swift\""
		core="not-drivable"
	fi

	run_id="${HOLDER_VERIFY_RUN_ID:-}"
	if [[ -z "$run_id" ]]; then
		echo "CORE run=unset hint=\"$0 launch\""
		core="not-drivable"
	else
		require_run
		if [[ ! -x "$binary" ]]; then
			echo "CORE run=$run_id binary=missing hint=\"$0 launch\""
			core="not-drivable"
		elif ! sources_fresh; then
			echo "CORE run=$run_id binary=stale hint=\"$0 launch\""
			core="not-drivable"
		else
			echo "CORE run=$run_id binary=fresh $(tr '\n' ' ' <"$run_dir/provenance.txt")"
		fi
	fi

	for check in "${glue_checks[@]}"; do
		file="${check%%|*}"
		needle="${check#*|}"
		if ! grep -qF -- "$needle" "$repo_root/$file"; then
			echo "CORE glue=drift file=$file missing=\"$needle\""
			core="not-drivable"
		fi
	done
	[[ "$core" == ok ]] && echo "CORE glue=ok checks=${#glue_checks[@]}"

	app_preflight || app="fail-closed"
	[[ "$core" == ok ]] || status=1
	echo "RESULT core=$core app=$app"
	return "$status"
}

cmd_drive() {
	[[ "${1:-}" == scan && -n "${2:-}" ]] || { echo "usage: $0 drive scan <fixture-name|path>" >&2; exit 2; }
	require_run
	[[ -x "$binary" ]] || fail_closed core not-launched
	sources_fresh || fail_closed core stale-build
	local fixture="$2"
	[[ -f "$fixture" ]] || fixture="$skill_dir/fixtures/$2.json"
	[[ -f "$fixture" ]] || fail_closed core no-fixture-"$2" 2
	fixture="$(cd "$(dirname "$fixture")" && pwd)/$(basename "$fixture")"

	local name evidence code=0
	name="$(basename "$fixture" .json)"
	evidence="$evidence_root/$run_id/scan-$name-$(date -u +%H%M%S)"
	mkdir -p "$evidence"
	cp "$fixture" "$evidence/fixture.json"
	cp "$run_dir/provenance.txt" "$evidence/provenance.txt"
	echo "$binary $fixture" >"$evidence/command.txt"
	"$binary" "$fixture" >"$evidence/stdout.txt" 2>"$evidence/stderr.txt" || code=$?
	echo "$code" >"$evidence/exit-code.txt"
	cat "$evidence/stdout.txt"
	echo "EVIDENCE dir=$evidence exit=$code"
	return "$code"
}

cmd_cleanup() {
	require_run
	if [[ -d "$run_dir" ]]; then
		rm -rf -- "$run_dir"
		echo "CLEANUP removed=$run_dir"
	else
		echo "CLEANUP removed=none run=$run_id"
	fi
	if [[ -d "$evidence_root/$run_id" ]]; then
		echo "EVIDENCE kept=$evidence_root/$run_id files=$(find "$evidence_root/$run_id" -type f | wc -l | tr -d ' ')"
	else
		echo "EVIDENCE kept=none run=$run_id"
	fi
}

case "${1:-}" in
	setup-swift) cmd_setup_swift ;;
	launch) cmd_launch ;;
	doctor) cmd_doctor ;;
	drive) shift; cmd_drive "$@" ;;
	cleanup) cmd_cleanup ;;
	app-preflight) app_preflight ;;
	*)
		echo "usage: $0 setup-swift|launch|doctor|drive scan <fixture>|cleanup|app-preflight" >&2
		exit 2
		;;
esac
