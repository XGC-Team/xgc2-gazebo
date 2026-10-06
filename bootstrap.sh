#!/usr/bin/env bash
# Build Gazebo Classic 11 from source into this checkout.
# The checkout can live anywhere. Archives, sources, build trees, and the
# install prefix stay under ./gazebo so the rest of the checkout is scripts.
# ./gazebo/usr mirrors the Focal apt layout under /usr.
# The script does not edit shell startup files and does not call ldconfig.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$ROOT/gazebo"
PREFIX="${XGC2_GAZEBO_PREFIX:-$WORK/usr}"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
MAX_JOBS=16

log() { printf '%s\n' "$*" >&2; }
die() { printf '%s\n' "$*" >&2; exit 1; }

job_count() {
  local jobs="${GAZEBO_BUILD_JOBS:-$MAX_JOBS}"
  local host avail_kb mem_jobs avail_gib
  [[ "$jobs" =~ ^[0-9]+$ ]] || die "GAZEBO_BUILD_JOBS must be a positive integer"
  if (( jobs < 1 || jobs > MAX_JOBS )); then
    if (( jobs > MAX_JOBS )); then
      log "GAZEBO_BUILD_JOBS=${jobs} is above the cap of ${MAX_JOBS}; using ${MAX_JOBS}"
      jobs=$MAX_JOBS
    else
      die "GAZEBO_BUILD_JOBS must be a positive integer"
    fi
  fi
  host="$(nproc)"
  if (( jobs > host )); then
    jobs=$host
  fi
  avail_kb="$(awk '/MemAvailable/ {print $2}' /proc/meminfo)"
  avail_gib=$(( avail_kb / 1024 / 1024 ))
  if [[ -z "${GAZEBO_BUILD_JOBS:-}" ]]; then
    mem_jobs=$(( avail_kb / 2000000 ))
    if (( mem_jobs < 1 )); then
      mem_jobs=1
    fi
    if (( jobs > mem_jobs )); then
      log "MemAvailable is about ${avail_gib} GiB; using ${mem_jobs} jobs"
      jobs=$mem_jobs
    fi
  elif (( avail_kb / 1500000 < jobs )); then
    log "GAZEBO_BUILD_JOBS=${jobs} with about ${avail_gib} GiB available. Lower it if the compiler is killed."
  fi
  printf '%s\n' "$jobs"
}

require_ubuntu() {
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${VERSION_ID:-}" != "24.04" && "${ALLOW_OTHER_UBUNTU:-}" != 1 ]]; then
    die "This branch builds on Ubuntu 24.04. This machine is ${PRETTY_NAME:-unknown}. Set ALLOW_OTHER_UBUNTU=1 to continue anyway."
  fi
}

require_user() {
  if [[ "$(id -u)" -eq 0 ]]; then
    die "Run ./bootstrap.sh as your user. It calls sudo only for apt."
  fi
}

list_words() {
  awk '{ sub(/#.*/, ""); if (NF) print $1 }' "$1"
}

source_field() {
  local name="$1" field="$2"
  awk -v name="$name" -v field="$field" '
    $1 == name { print $field; exit }
  ' "$ROOT/sources.txt"
}

components() {
  list_words "$ROOT/sources.txt"
}

cmd_deps() {
  require_ubuntu
  require_user
  log "Installing host libraries with sudo. Gazebo itself is built from source."
  sudo -v
  sudo apt-get update
  # shellcheck disable=SC2046
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $(list_words "$ROOT/apt-host.txt")
}

download_one() {
  local name="$1" sha url dest
  sha="$(source_field "$name" 2)"
  url="$(source_field "$name" 3)"
  [[ -n "$sha" && -n "$url" ]] || die "sources.txt has no entry for ${name}"
  mkdir -p "$WORK/cache"
  dest="$WORK/cache/${name}.tar.gz"
  if [[ -f "$dest" ]] && echo "${sha}  ${dest}" | sha256sum -c - >/dev/null; then
    log "Using cached ${name}"
    return 0
  fi
  command -v wget >/dev/null || die "wget is missing. Run ./bootstrap.sh deps first."
  log "Downloading ${name}"
  wget -c --timeout=60 --tries=2 --progress=dot:giga -O "$dest" "$url" || die "failed to download ${url}"
  echo "${sha}  ${dest}" | sha256sum -c - || die "checksum mismatch for ${name}"
}

cmd_fetch() {
  local name
  while IFS= read -r name; do
    download_one "$name"
    if [[ ! -f "$WORK/src/${name}/CMakeLists.txt" ]]; then
      log "Extracting ${name}"
      mkdir -p "$WORK/src/${name}"
      tar -xf "$WORK/cache/${name}.tar.gz" -C "$WORK/src/${name}" --strip-components=1
    fi
  done < <(components)
}

prepare_prefix_env() {
  export CMAKE_PREFIX_PATH="${PREFIX}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
  local libdir="${PREFIX}/lib/x86_64-linux-gnu"
  export PKG_CONFIG_PATH="${libdir}/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
  export LD_LIBRARY_PATH="${libdir}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
}

build_one() {
  local name="$1" jobs="$2" sha src bld stamp
  sha="$(source_field "$name" 2)"
  src="$WORK/src/${name}"
  bld="$WORK/build/${name}"
  stamp="$WORK/stamps/${name}"
  [[ -f "$src/CMakeLists.txt" ]] || die "${name} source is missing. Run ./bootstrap.sh fetch first."
  if [[ -f "$stamp" && "$(tr -d '[:space:]' < "$stamp")" == "$sha" ]]; then
    log "${name} is already installed"
    return 0
  fi
  local -a extra=()
  case "$name" in
    sdformat)
      extra+=(-DUSE_INTERNAL_URDF=ON -DSKIP_PYBIND11=ON)
      ;;
    ignition-math|ignition-common|ignition-msgs|ignition-transport|ignition-fuel-tools)
      extra+=(-DSKIP_PYBIND11=ON)
      ;;
  esac
  log "Building ${name} into ${PREFIX}"
  cmake -S "$src" -B "$bld" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=lib/x86_64-linux-gnu \
    -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DCMAKE_INSTALL_RPATH="${PREFIX}/lib/x86_64-linux-gnu;${PREFIX}/lib" \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
    -DBUILD_TESTING=OFF \
    "${extra[@]}"
  cmake --build "$bld" -j"$jobs"
  cmake --install "$bld"
  mkdir -p "$WORK/stamps"
  printf '%s\n' "$sha" > "$stamp"
}

cmd_build() {
  require_ubuntu
  local jobs name
  jobs="$(job_count)"
  prepare_prefix_env
  while IFS= read -r name; do
    build_one "$name" "$jobs"
  done < <(components)
}

cmd_smoke() {
  [[ -x "${PREFIX}/bin/gazebo" ]] || die "gazebo is missing under ${PREFIX}"
  [[ -f "${PREFIX}/lib/x86_64-linux-gnu/libgazebo.so.11" ]] || die "libgazebo.so.11 is missing"
  [[ -f "${PREFIX}/lib/x86_64-linux-gnu/cmake/gazebo/gazebo-config.cmake" ]] || die "gazebo-config.cmake is missing"
  [[ -d "${PREFIX}/lib/x86_64-linux-gnu/gazebo-11/plugins" ]] || die "Gazebo plugins are missing"
  local reported
  reported="$(
    PATH="${PREFIX}/bin:${PATH}" \
    LD_LIBRARY_PATH="${PREFIX}/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
      "${PREFIX}/bin/gazebo" --version
  )"
  printf '%s\n' "$reported" | grep -q "${VERSION}" || die "gazebo --version did not report ${VERSION}: ${reported}"
  PKG_CONFIG_PATH="${PREFIX}/lib/x86_64-linux-gnu/pkgconfig" pkg-config --exists gazebo \
    || die "pkg-config cannot see gazebo"
  log "Smoke check passed for Gazebo ${VERSION} at ${PREFIX}."
  log "Load this prefix when you need it: source env.bash"
  log "Shell startup files were not modified."
}

usage() {
  cat <<EOF
Usage: ./bootstrap.sh [all|deps|fetch|build]

  all     host libraries, source download, build, install, smoke check (default)
  deps    apt libraries used to compile Gazebo Classic
  fetch   download and extract the pinned sources into ./gazebo
  build   compile the stack into ./gazebo/usr and run the smoke check

Gazebo ${VERSION} installs to ${PREFIX}.
That directory mirrors Focal's /usr layout for gazebo11.
Compilation uses at most ${MAX_JOBS} cores, and fewer when memory is tight.
Set GAZEBO_BUILD_JOBS to choose the job count, still capped at ${MAX_JOBS}.
If a build stops, run ./bootstrap.sh build to continue it.
EOF
}

main() {
  local cmd="${1:-all}"
  case "$cmd" in
    all)
      cmd_deps
      cmd_fetch
      cmd_build
      cmd_smoke
      ;;
    deps) cmd_deps ;;
    fetch) cmd_fetch ;;
    build)
      cmd_build
      cmd_smoke
      ;;
    -h|--help|help) usage ;;
    *)
      usage
      die "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
