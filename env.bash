# Load this checkout's Gazebo Classic prefix into the current shell.
# Usage: source env.bash
# Do not add this file to a shell startup file.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf '%s\n' "source env.bash" >&2
  exit 1
fi

_xgc2_gz_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_xgc2_gz_prefix="${XGC2_GAZEBO_PREFIX:-${_xgc2_gz_root}/gazebo/usr}"

if [[ ! -x "${_xgc2_gz_prefix}/bin/gazebo" ]]; then
  printf '%s\n' "gazebo is missing under ${_xgc2_gz_prefix}. From ${_xgc2_gz_root} run ./bootstrap.sh" >&2
  unset _xgc2_gz_root _xgc2_gz_prefix
  return 1
fi

if [[ -d "${_xgc2_gz_prefix}/lib/x86_64-linux-gnu" ]]; then
  _xgc2_gz_lib="${_xgc2_gz_prefix}/lib/x86_64-linux-gnu"
else
  _xgc2_gz_lib="${_xgc2_gz_prefix}/lib"
fi
_xgc2_gz_plugins="${_xgc2_gz_lib}/gazebo-11/plugins"

_xgc2_gz_prepend() {
  local name="$1" value="$2" current
  current="${!name-}"
  case ":${current}:" in
    *":${value}:"*) ;;
    *) export "${name}=${value}${current:+:${current}}" ;;
  esac
}

export XGC2_GAZEBO_PREFIX="${_xgc2_gz_prefix}"
export GAZEBO_INSTALL_PREFIX="${_xgc2_gz_prefix}"
export GAZEBO_MASTER_URI="${GAZEBO_MASTER_URI:-http://localhost:11345}"
export GAZEBO_MODEL_DATABASE_URI="${GAZEBO_MODEL_DATABASE_URI:-http://models.gazebosim.org}"
_xgc2_gz_prepend GAZEBO_RESOURCE_PATH "${_xgc2_gz_prefix}/share/gazebo-11"
_xgc2_gz_prepend GAZEBO_MODEL_PATH "${_xgc2_gz_prefix}/share/gazebo-11/models"
_xgc2_gz_prepend GAZEBO_PLUGIN_PATH "${_xgc2_gz_plugins}"
export OGRE_RESOURCE_PATH="${OGRE_RESOURCE_PATH:-/usr/lib/x86_64-linux-gnu/OGRE-1.9.0}"

_xgc2_gz_prepend PATH "${_xgc2_gz_prefix}/bin"
_xgc2_gz_prepend CMAKE_PREFIX_PATH "${_xgc2_gz_prefix}"
_xgc2_gz_prepend PKG_CONFIG_PATH "${_xgc2_gz_lib}/pkgconfig"
_xgc2_gz_prepend LD_LIBRARY_PATH "${_xgc2_gz_lib}"
_xgc2_gz_prepend LD_LIBRARY_PATH "${_xgc2_gz_plugins}"

unset -f _xgc2_gz_prepend
unset _xgc2_gz_root _xgc2_gz_prefix _xgc2_gz_lib _xgc2_gz_plugins
