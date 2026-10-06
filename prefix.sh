# Load Gazebo Classic from its own prefix.
# Source this file. Do not execute it.
# /opt/ros/noetic/setup.bash sources it. A standalone checkout can source it
# after setting XGC2_GAZEBO_PREFIX. Nothing here is installed into /usr.

if [ -n "${XGC2_GAZEBO_PREFIX:-}" ]; then
  _xgc2_gz_prefix=$XGC2_GAZEBO_PREFIX
else
  _xgc2_gz_prefix=/opt/ros/noetic/opt/gazebo
fi

if [ ! -x "${_xgc2_gz_prefix}/bin/gazebo" ]; then
  unset _xgc2_gz_prefix
  return 0
fi

_xgc2_gz_lib="${_xgc2_gz_prefix}/lib"
if [ -d "${_xgc2_gz_prefix}/lib/x86_64-linux-gnu" ]; then
  _xgc2_gz_lib="${_xgc2_gz_prefix}/lib/x86_64-linux-gnu"
elif [ -d "${_xgc2_gz_prefix}/lib/aarch64-linux-gnu" ]; then
  _xgc2_gz_lib="${_xgc2_gz_prefix}/lib/aarch64-linux-gnu"
fi

_xgc2_gz_prepend() {
  _xgc2_gz_name=$1
  _xgc2_gz_value=$2
  eval "_xgc2_gz_current=\${${_xgc2_gz_name}-}"
  case ":${_xgc2_gz_current}:" in
    *":${_xgc2_gz_value}:"*) ;;
    *)
      if [ -n "${_xgc2_gz_current}" ]; then
        eval "export ${_xgc2_gz_name}=\"${_xgc2_gz_value}:${_xgc2_gz_current}\""
      else
        eval "export ${_xgc2_gz_name}=\"${_xgc2_gz_value}\""
      fi
      ;;
  esac
}

export XGC2_GAZEBO_PREFIX="${_xgc2_gz_prefix}"
export GAZEBO_INSTALL_PREFIX="${_xgc2_gz_prefix}"
if [ -z "${GAZEBO_MASTER_URI:-}" ]; then
  export GAZEBO_MASTER_URI=http://localhost:11345
fi
if [ -z "${GAZEBO_MODEL_DATABASE_URI:-}" ]; then
  export GAZEBO_MODEL_DATABASE_URI=http://models.gazebosim.org
fi

_xgc2_gz_prepend GAZEBO_RESOURCE_PATH "${_xgc2_gz_prefix}/share/gazebo-11"
_xgc2_gz_prepend GAZEBO_MODEL_PATH "${_xgc2_gz_prefix}/share/gazebo-11/models"
_xgc2_gz_prepend GAZEBO_PLUGIN_PATH "${_xgc2_gz_lib}/gazebo-11/plugins"

if [ -z "${OGRE_RESOURCE_PATH:-}" ]; then
  if [ -d /usr/lib/x86_64-linux-gnu/OGRE-1.9.0 ]; then
    export OGRE_RESOURCE_PATH=/usr/lib/x86_64-linux-gnu/OGRE-1.9.0
  elif [ -d /usr/lib/aarch64-linux-gnu/OGRE-1.9.0 ]; then
    export OGRE_RESOURCE_PATH=/usr/lib/aarch64-linux-gnu/OGRE-1.9.0
  fi
fi

_xgc2_gz_prepend PATH "${_xgc2_gz_prefix}/bin"
_xgc2_gz_prepend CMAKE_PREFIX_PATH "${_xgc2_gz_prefix}"
_xgc2_gz_prepend PKG_CONFIG_PATH "${_xgc2_gz_lib}/pkgconfig"
_xgc2_gz_prepend LD_LIBRARY_PATH "${_xgc2_gz_lib}"
_xgc2_gz_prepend LD_LIBRARY_PATH "${_xgc2_gz_lib}/gazebo-11/plugins"

unset -f _xgc2_gz_prepend
unset _xgc2_gz_prefix _xgc2_gz_lib _xgc2_gz_name _xgc2_gz_value _xgc2_gz_current
