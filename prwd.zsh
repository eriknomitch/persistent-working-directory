# ================================================
# PERSISTENT-WORKING-DIRECTORY ===================
# ================================================

# ------------------------------------------------
# GLOBALS ----------------------------------------
# ------------------------------------------------
WORKING_DIRECTORY_FILE=$HOME/.prwd-directories

# If the user has not set PRWD_BIND_TO_WORKSPACE, default to false.
if [[ -z $PRWD_BIND_TO_WORKSPACE ]] ; then
  PRWD_BIND_TO_WORKSPACE=false
fi

# If the user has not set PRWD_BIND_TO_TMUX, default to false.
if [[ -z $PRWD_BIND_TO_TMUX ]] ; then
  PRWD_BIND_TO_TMUX=false
fi

# ------------------------------------------------
# UTILITY ----------------------------------------
# ------------------------------------------------
function _in_tmux() {
  if test -z $TMUX; then
    return 1
  fi
  return 0
}

function _current_workspace()
{
  # Clients SSHed here get their own workspace
  if ( env | grep -q "^SSH_CLIENT=" ) ; then
    echo "ssh"
  # If the config is set to bind within tmux and we're in a tmux...
  elif ( $PRWD_BIND_TO_TMUX && `_in_tmux` ) ; then
    echo $TMUX | \grep -oE "([0-9]*$)"
  # If the config is set to bind to a workspace...
  elif ( $PRWD_BIND_TO_WORKSPACE ) ; then
    wmctrl -d | grep "*" | awk '{print $1}'
  # Otherwise we're "always on 'none'"
  else
    echo "none"
  fi
}

function _get_persistent_working_directory()
{
  local _target=$1
  local _workspace=$2

  cat $WORKING_DIRECTORY_FILE | grep -E "^$_target,$_workspace," | sed "s/^$_target,$_workspace,//"
}

# ------------------------------------------------
# COMMANDS ---------------------------------------
# ------------------------------------------------
function lw()
{
  # List the current working directory
  if [[ $1 == "-c" ]] ; then

    _get_persistent_working_directory 0 `_current_workspace`

  # We want to see a specific workspace
  elif [[ -n $1 ]] ; then

    _get_persistent_working_directory 0 $1

  # List entire file
  else
    test -e $WORKING_DIRECTORY_FILE && cat $WORKING_DIRECTORY_FILE | sort
  fi
}

function sw()
{
  local _target=$1
  local _workspace=$2

  if [[ -z $_target ]] ; then
    _target="none"
  fi

  if [[ -z $_workspace ]] ; then
    _workspace=`_current_workspace`
  fi

  # Destroy the target if it exists
  if [[ -e $WORKING_DIRECTORY_FILE ]] ; then

    # macOS sed is different and takes a preliminary "backup" arg
    # but the user could have GNU sed installed.
    #
    # The macOS sed returns an error with the --help flag passed.
    if sed --help > /dev/null 2>&1; then
      # GNU sed
      sed -i "/^$_target,$_workspace,.*$/d" $WORKING_DIRECTORY_FILE
    else
      # macOS sed requires a hack. This .tmp file has to be created for
      # in-place to work.
      sed -i.tmp "/^$_target,$_workspace,.*$/d" $WORKING_DIRECTORY_FILE

      test -f $WORKING_DIRECTORY_FILE.tmp && rm $WORKING_DIRECTORY_FILE.tmp
    fi
  fi

  # Add it to the working directory file
  echo "$_target,$_workspace,$PWD" >> $WORKING_DIRECTORY_FILE

  lw -c
}

function gw()
{
  local _target=$1
  local _workspace="none"
  local _list_target=false

  # Handle --list-target if we just want to list the
  # target directory and not actually cd there.
  if [[ $_target == "--list-target" ]] ; then
    shift
    _target=$1
    _list_target=true
  fi

  # Default to 0 if target was not passed
  if [[ -z $_target ]] ; then
    _target="none"
  fi

  # Default to 0 if we aren't binding to workspaces
  if ( $PRWD_BIND_TO_WORKSPACE || $PRWD_BIND_TO_TMUX ) ; then
    _workspace=`_current_workspace`
  fi

  if [[ -e $WORKING_DIRECTORY_FILE ]] ; then

    local _directory=`_get_persistent_working_directory $_target $_workspace`

    if ( $_list_target ) ; then
      echo $_directory
      return
    fi

    clear

    if [[ -z $_directory ]] ; then
      echo "$0: Working directory not set for target=$_target workspace=$_workspace. Changing directory to '~/'."

      cd

      # FIX:
      if ( `(command -v g >/dev/null 2>&1)` ) ; then
        g
      fi

    else
      cd $_directory
    fi
  else
    echo "$0: No directories are set. Changing directory to '~/'."
    cd
    return
  fi
}

# Clear working directory file
function cw()
{
  if [[ -f $WORKING_DIRECTORY_FILE ]] ; then
    rm $WORKING_DIRECTORY_FILE
    echo "Cleared persistent working directories."
  else
    echo "No persistent working directory file to clear."
  fi
}

function pwd-is-wd() {
  if [[ `pwd` == `gw --list-target` ]] ; then
    return 0
  fi
  return 1
}

function _ensure_default_working_directory_file()
{
  # Create the file and set a default working directory (HOME)
  if [[ ! -f $WORKING_DIRECTORY_FILE ]] ; then
    echo "0,0,$HOME" >> $WORKING_DIRECTORY_FILE
  fi
}

# ------------------------------------------------
# MAIN -------------------------------------------
# ------------------------------------------------
#_ensure_default_working_directory_file

