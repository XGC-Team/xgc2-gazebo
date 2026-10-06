# Load this checkout's Gazebo Classic prefix into the current shell.
# Usage: source env.bash
# Do not add this file to a shell startup file.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf '%s\n' "source env.bash" >&2
  exit 1
fi

_xgc2_gz_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export XGC2_GAZEBO_PREFIX="${XGC2_GAZEBO_PREFIX:-${_xgc2_gz_root}/gazebo/usr}"

if [[ ! -x "${XGC2_GAZEBO_PREFIX}/bin/gazebo" ]]; then
  printf '%s\n' "gazebo is missing under ${XGC2_GAZEBO_PREFIX}. From ${_xgc2_gz_root} run ./bootstrap.sh" >&2
  unset _xgc2_gz_root
  return 1
fi

# shellcheck disable=SC1091
source "${_xgc2_gz_root}/prefix.sh"
unset _xgc2_gz_root
