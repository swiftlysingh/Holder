#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_PATH="${REPO_ROOT}/cards.xcodeproj"
PACKAGE_RESOLVED="${PROJECT_PATH}/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

ACTION="build"
SCHEME="cards"
CONFIGURATION="Debug"
DESTINATION=""
JOBS="${HOLDER_XCODE_JOBS:-6}"
DERIVED_DATA="${HOLDER_DERIVED_DATA_PATH:-${REPO_ROOT}/.build/DerivedData}"
CACHE_ROOT="${HOLDER_XCODE_CACHE_ROOT:-}"
CAS_LIMIT_SIZE="${HOLDER_CAS_LIMIT_SIZE:-20G}"
ENABLE_CACHE=1
SHOW_TIMING=0
CACHE_REMARKS=0
QUIET=0
CLEAN_DERIVED_DATA=0
ALLOW_PACKAGE_RESOLUTION=0
ALL_TESTS=0
ALL_ARCHS=0
PARALLEL_TESTING=0
ONLY_TESTING=()
EXTRA_ARGS=()

usage() {
  cat <<'EOF'
Usage: Scripts/agent-build.sh [action] [options] [-- extra xcodebuild args]

Actions:
  build                 Compile Holder for iOS Simulator (default; no simulator boot)
  test                  Build and run unit tests (cardsTests by default)
  build-for-testing     Build app and tests for iOS Simulator without running tests
  test-without-building Run tests using existing build products
  resolve               Resolve SwiftPM packages into the shared cache

Options:
  --scheme <name>              Xcode scheme (default: cards)
  --configuration <cfg>        Debug, Beta, or Release (default: Debug)
  --destination <spec>         Explicit xcodebuild -destination value
  --only-testing <target/test> Restrict tests (repeatable; overrides default cardsTests)
  --all-tests                  Run all test targets in scheme (including any UI tests)
  --all-archs                  Build all simulator architectures (default: host arch only in Debug)
  --parallel-testing           Allow Xcode parallel test simulator clones
  --jobs <n>                   Max concurrent xcodebuild jobs (default: 6)
  --derived-data <path>        Worktree-local DerivedData path (default: <repo>/.build/DerivedData)
  --cache-root <path>          Shared CAS + SourcePackages root
  --no-cache                   Disable Xcode compilation caching (CAS)
  --timing                     Pass -showBuildTimingSummary
  --cache-remarks              Emit COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES
  --quiet                      Pass -quiet to xcodebuild
  --clean-derived-data         Delete worktree-local DerivedData before running (keeps shared CAS/SPM)
  --allow-package-resolution   Allow SwiftPM network resolution / updates
  -h, --help                   Show this help

Environment overrides:
  HOLDER_XCODE_CACHE_ROOT
  HOLDER_DERIVED_DATA_PATH
  HOLDER_XCODE_JOBS
  HOLDER_CAS_LIMIT_SIZE
  HOLDER_SIMULATOR_DESTINATION
EOF
}

require_value() {
  if [[ $# -lt 2 || -z "$2" ]]; then
    echo "Missing value for $1" >&2
    exit 2
  fi
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    build|test|build-for-testing|test-without-building|resolve)
      ACTION="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
  esac
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      require_value "$@"
      SCHEME="$2"
      shift 2
      ;;
    --configuration)
      require_value "$@"
      CONFIGURATION="$2"
      shift 2
      ;;
    --destination)
      require_value "$@"
      DESTINATION="$2"
      shift 2
      ;;
    --only-testing)
      require_value "$@"
      ONLY_TESTING+=("$2")
      shift 2
      ;;
    --all-tests)
      ALL_TESTS=1
      shift
      ;;
    --all-archs)
      ALL_ARCHS=1
      shift
      ;;
    --parallel-testing)
      PARALLEL_TESTING=1
      shift
      ;;
    --jobs)
      require_value "$@"
      JOBS="$2"
      shift 2
      ;;
    --derived-data)
      require_value "$@"
      DERIVED_DATA="$2"
      shift 2
      ;;
    --cache-root)
      require_value "$@"
      CACHE_ROOT="$2"
      shift 2
      ;;
    --no-cache)
      ENABLE_CACHE=0
      shift
      ;;
    --timing)
      SHOW_TIMING=1
      shift
      ;;
    --cache-remarks)
      CACHE_REMARKS=1
      shift
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    --clean-derived-data)
      CLEAN_DERIVED_DATA=1
      shift
      ;;
    --allow-package-resolution)
      ALLOW_PACKAGE_RESOLUTION=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      if [[ $# -gt 0 ]]; then
        EXTRA_ARGS+=("$@")
      fi
      break
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "${CACHE_ROOT}" ]]; then
  if [[ -d "/Volumes/Atlas/Developer" && -w "/Volumes/Atlas/Developer" ]]; then
    CACHE_ROOT="/Volumes/Atlas/Developer/XcodeCache"
  else
    CACHE_ROOT="${HOME}/Library/Caches/XcodeCache"
  fi
fi

CAS_PATH="${CACHE_ROOT}/CAS"
SOURCE_PACKAGES_DIR="${CACHE_ROOT}/SourcePackages/Holder"
SPM_STAMP_FILE="${SOURCE_PACKAGES_DIR}/.holder-package-resolved.sha256"
SPM_LOCK_DIR="${CACHE_ROOT}/.holder-spm-resolve.lock"

mkdir -p "${CAS_PATH}" "${SOURCE_PACKAGES_DIR}"

if [[ "${CLEAN_DERIVED_DATA}" -eq 1 && -d "${DERIVED_DATA}" ]]; then
  rm -rf "${DERIVED_DATA}"
fi
mkdir -p "${DERIVED_DATA}"

detect_simulator_destination() {
  if [[ -n "${HOLDER_SIMULATOR_DESTINATION:-}" ]]; then
    printf '%s\n' "${HOLDER_SIMULATOR_DESTINATION}"
    return 0
  fi

  local udid=""
  if command -v python3 >/dev/null 2>&1; then
    udid="$(xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import json, re, sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

def runtime_version(runtime):
    m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?", runtime)
    if not m:
        return (0, 0, 0)
    return tuple(int(x or 0) for x in m.groups())

named_iphones = []
type_iphones = []
for runtime, items in data.get("devices", {}).items():
    if "SimRuntime.iOS-" not in runtime:
        continue
    ver = runtime_version(runtime)
    for d in items:
        if not d.get("isAvailable"):
            continue
        name = d.get("name", "")
        dtype = d.get("deviceTypeIdentifier", "")
        if "iPhone" in name:
            named_iphones.append((ver, d))
        elif "iPhone" in dtype:
            type_iphones.append((ver, d))

def pick(candidates):
    if not candidates:
        return None
    booted = sorted(
        [(ver, d) for ver, d in candidates if d.get("state") == "Booted"],
        key=lambda x: x[0],
        reverse=True,
    )
    if booted:
        return booted[0][1]["udid"]
    ranked = sorted(candidates, key=lambda x: x[0], reverse=True)
    preferred = (
        "iPhone 18 Pro",
        "iPhone 18",
        "iPhone 17 Pro",
        "iPhone 17",
        "iPhone 17e",
        "iPhone 16 Pro",
        "iPhone 16",
    )
    for pref in preferred:
        for _, d in ranked:
            if d.get("name") == pref:
                return d["udid"]
    return ranked[0][1]["udid"]

chosen = pick(named_iphones) or pick(type_iphones)
if chosen:
    print(chosen)
' || true)"
  fi

  if [[ -n "${udid}" ]]; then
    printf 'platform=iOS Simulator,id=%s\n' "${udid}"
  else
    printf 'platform=iOS Simulator,name=iPhone 18 Pro\n'
  fi
}

if [[ -z "${DESTINATION}" ]]; then
  case "${ACTION}" in
    build|build-for-testing)
      DESTINATION="generic/platform=iOS Simulator"
      ;;
    test|test-without-building)
      DESTINATION="$(detect_simulator_destination)"
      ;;
    resolve)
      DESTINATION=""
      ;;
  esac
fi

RESOLVED_SHA=""
if [[ -f "${PACKAGE_RESOLVED}" ]]; then
  RESOLVED_SHA="$(shasum -a 256 "${PACKAGE_RESOLVED}" | awk '{print $1}')"
fi

acquire_spm_lock() {
  local attempts=0
  while ! mkdir "${SPM_LOCK_DIR}" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [[ "${attempts}" -ge 5 && -f "${SPM_LOCK_DIR}/pid" ]]; then
      local lock_pid=""
      lock_pid="$(cat "${SPM_LOCK_DIR}/pid" 2>/dev/null || true)"
      if [[ "${lock_pid}" =~ ^[0-9]+$ ]] && ! kill -0 "${lock_pid}" 2>/dev/null; then
        rm -rf "${SPM_LOCK_DIR}" 2>/dev/null || true
        continue
      fi
    fi
    if [[ "${attempts}" -ge 300 ]]; then
      echo "Timed out waiting for SwiftPM resolve lock at ${SPM_LOCK_DIR}" >&2
      exit 1
    fi
    sleep 1
  done
  printf '%s\n' "$$" > "${SPM_LOCK_DIR}/pid"
  trap 'rm -rf "${SPM_LOCK_DIR}" 2>/dev/null || true' EXIT
}

release_spm_lock() {
  rm -rf "${SPM_LOCK_DIR}" 2>/dev/null || true
  trap - EXIT
}

needs_spm_resolve() {
  if [[ "${ACTION}" == "resolve" || "${ALLOW_PACKAGE_RESOLUTION}" -eq 1 ]]; then
    return 0
  fi
  if [[ ! -d "${SOURCE_PACKAGES_DIR}/checkouts" ]]; then
    return 0
  fi
  if [[ -n "${RESOLVED_SHA}" ]]; then
    if [[ ! -f "${SPM_STAMP_FILE}" ]] || [[ "$(cat "${SPM_STAMP_FILE}" 2>/dev/null || true)" != "${RESOLVED_SHA}" ]]; then
      return 0
    fi
  fi
  return 1
}

if needs_spm_resolve; then
  acquire_spm_lock
  if needs_spm_resolve; then
    resolve_cmd=(
      xcodebuild
      -resolvePackageDependencies
      -project "${PROJECT_PATH}"
      -scheme "${SCHEME}"
      -derivedDataPath "${DERIVED_DATA}"
      -clonedSourcePackagesDirPath "${SOURCE_PACKAGES_DIR}"
    )
    if [[ "${ALLOW_PACKAGE_RESOLUTION}" -eq 0 ]]; then
      resolve_cmd+=(-onlyUsePackageVersionsFromResolvedFile)
    fi
    if [[ "${QUIET}" -eq 1 ]]; then
      resolve_cmd+=(-quiet)
    fi
    "${resolve_cmd[@]}"
    if [[ -f "${PACKAGE_RESOLVED}" ]]; then
      RESOLVED_SHA="$(shasum -a 256 "${PACKAGE_RESOLVED}" | awk '{print $1}')"
      printf '%s\n' "${RESOLVED_SHA}" > "${SPM_STAMP_FILE}"
    fi
  fi
  release_spm_lock
fi

if [[ "${ACTION}" == "resolve" ]]; then
  exit 0
fi

cmd=(
  xcodebuild
  -project "${PROJECT_PATH}"
  -scheme "${SCHEME}"
  -configuration "${CONFIGURATION}"
  -destination "${DESTINATION}"
  -derivedDataPath "${DERIVED_DATA}"
  -clonedSourcePackagesDirPath "${SOURCE_PACKAGES_DIR}"
  -jobs "${JOBS}"
  -parallelizeTargets
)

if [[ "${ALLOW_PACKAGE_RESOLUTION}" -eq 0 ]]; then
  cmd+=(
    -onlyUsePackageVersionsFromResolvedFile
    -skipPackageUpdates
    -disableAutomaticPackageResolution
  )
fi

if [[ "${QUIET}" -eq 1 ]]; then
  cmd+=(-quiet)
fi

if [[ "${SHOW_TIMING}" -eq 1 ]]; then
  cmd+=(-showBuildTimingSummary)
fi

if [[ "${ACTION}" == "test" || "${ACTION}" == "test-without-building" ]]; then
  cmd+=(-enableCodeCoverage NO)
  if [[ "${PARALLEL_TESTING}" -eq 0 ]]; then
    cmd+=(
      -parallel-testing-enabled NO
      -maximum-concurrent-test-simulator-destinations 1
    )
  fi
  if [[ "${ALL_TESTS}" -eq 0 ]]; then
    if [[ "${#ONLY_TESTING[@]}" -gt 0 ]]; then
      for spec in "${ONLY_TESTING[@]}"; do
        cmd+=("-only-testing:${spec}")
      done
    else
      cmd+=("-only-testing:cardsTests")
    fi
  fi
fi

# Strip work CLI agents do not need in Debug builds
if [[ "${CONFIGURATION}" == "Debug" ]]; then
  cmd+=(
    COMPILER_INDEX_STORE_ENABLE=NO
    SWIFT_EMIT_LOC_STRINGS=NO
    ENABLE_PREVIEWS=NO
    ENABLE_CODE_COVERAGE=NO
    CLANG_COVERAGE_MAPPING=NO
  )
fi

if [[ "${DESTINATION}" == *"iOS Simulator"* ]]; then
  if [[ "${CONFIGURATION}" == "Debug" && "${ALL_ARCHS}" -eq 0 ]]; then
    cmd+=(
      "ARCHS=$(uname -m)"
      ONLY_ACTIVE_ARCH=YES
    )
  fi
else
  cmd+=(CODE_SIGNING_ALLOWED=NO)
fi

if [[ "${ENABLE_CACHE}" -eq 1 ]]; then
  cmd+=(
    COMPILATION_CACHE_ENABLE_CACHING=YES
    "COMPILATION_CACHE_CAS_PATH=${CAS_PATH}"
    "COMPILATION_CACHE_LIMIT_SIZE=${CAS_LIMIT_SIZE}"
    SWIFT_ENABLE_PREFIX_MAPPING=YES
    SWIFT_ENABLE_PROJECT_PREFIX_MAPPING=YES
    CLANG_ENABLE_PREFIX_MAPPING=YES
    CLANG_ENABLE_PROJECT_PREFIX_MAPPING=YES
  )
  if [[ "${CACHE_REMARKS}" -eq 1 ]]; then
    cmd+=(COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES)
  fi
else
  cmd+=(COMPILATION_CACHE_ENABLE_CACHING=NO)
fi

if [[ "${#EXTRA_ARGS[@]}" -gt 0 ]]; then
  cmd+=("${EXTRA_ARGS[@]}")
fi

cmd+=("${ACTION}")

exec "${cmd[@]}"
