#!/bin/bash

set -o errexit

# *** GLOBAL VARIABLES ***
# environment: dev/prod (default: dev)
dc_env="${DC_ENV:-dev}"
# mode: compose/stack (default: if dc_env==prod then stack else compose)
dc_mode=$DC_MODE
if [ -z $dc_mode ]; then
  dc_mode="compose" # running mode
  if [ "$dc_env" == "prod" ]; then
    dc_mode="stack"
  fi
fi
# fs: ways to pass yml files to 'docker stack deploy'
dc_fs=$DC_FS
if [ -z $dc_fs ]; then
  dc_fs="conf"
fi

# cmd="docker-compose"  # command
# if [ "$dc_mode" == "stack" ]; then
#   cmd="docker stack"
# fi

# service definition yml files
srvs="<file_opt> docker-compose.yml \\"


# *** MAIN ***
main() {
  # compose service
  srvs_files $svc 'base'
  srvs_files $svc $dc_env

  # build the command (cmd)
  # docker stack
  if [ "$dc_mode" == "stack" ]; then
    # config -> use docker-compose
    if [ "$1" == "config" -o "$1" == "build" ]; then
      cmd="$(cmd_compose $@)"
    else
      cmd="$(cmd_stack $@)"
    fi
    # up/deploy/start -> deploy
    if [ "$1" == "up" -o "$1" == "deploy" -o "$1" == "start" ]; then
      #cmd="$cmd deploy \\"$'\n'"  $srvs"
      shift 1
      cmd="$(cmd_stack $(echo deploy $@))"
    fi
  fi
  # docker-compose
  if [ "$dc_mode" == "compose" ]; then
    cmd="$(cmd_compose $@)"
  fi

  # display/run the cmd
  echo "$cmd"
  if [ $cmd_echo == 0 ]; then
    echo "----------------------------------------------------"
    bash -c "$cmd"
  fi
}

# *** HELPERS ***

# -------------------------------------
# Composes the docker-compose command
#
# Globals:
#   srvs - service files variable
# Arguments:
#   cmd - docker-compose command
# Returns:
#   None
cmd_compose() {
  local cmdCompose="docker-compose"

  # add the name
  srvs="${srvs}"$'\n'"  -p $svc \\"
  cmdCompose="docker-compose \\"$'\n'"  $srvs"$'\n'"  $@"

  # set file option
  cmdCompose=$(echo "$cmdCompose" | sed "s/<file_opt>/-f/")

  echo "$cmdCompose"
}

# -------------------------------------
# Composes the docker stack command
#
# Globals:
#   srvs - service files variable
#   $@ - 
# Arguments:
#   none
# Returns:
#   None
cmd_stack() {
  local cmdStack="docker stack \\"$'\n'

  if [ "$1" == "deploy" ]; then
    #cmdStack="$cmdStack  deploy \\"
    if [ "$dc_fs" == "file" ]; then
      cmdStack="$cmdStack"$'\n'"  $srvs"
    else
      cmdC="$(cmd_compose config)"
      #cmdC=$(echo "$cmdC" | sed "s/  /      /")
      cmdStack="$cmdC \\"$'\n'"| $cmdStack  deploy \\"$'\n'"  --compose-file - \\"
    fi
    shift 1
  else
    cmdStack="$cmdStack  $1 \\"
    shift 1
  fi

  # add the rest
  if [ $# != 0 ]; then
    cmdStack="$cmdStack"$'\n'"  $@ \\"
  fi

  # add the name
  cmdStack="$cmdStack"$'\n'"  $svc"

  # set file option
  cmdStack=$(echo "$cmdStack" | sed "s/<file_opt>/-c/")

  echo "$cmdStack"
}

# -------------------------------------
# Composes the service definition yml files
#
# Globals:
#   srvs - service files variable
# Arguments:
#   $1 - service name
#   $2 - enviroment (default: dev)
# Returns:
#   None
srvs_files() {
  # service
  local service=$1
  # enviroment (default: dev)
  local env="${2:-dev}"

  srvs="${srvs}"$'\n'"  <file_opt> services/$service/docker-compose.$env.yml \\"
}

# -------------------------------------
# Shows usage/help
#
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
show_usage() {
  echo "Run service with docker-compose/docker stack (DC_MODE) in dev/prod (DC_ENV) environment."
  echo
  echo "Usage:"
  echo "  ./dc.sh [flag] SERVICE [options] [command] [args...]"
  echo
  echo "Environment variables:"
  echo "  DC_ENV      Enviroment [ dev | prod ]; default: dev"
  echo "  DC_MODE     Used docker command [ compose | stack ]; default: if DC_ENV==prod then 'stack' else 'compose'"
  echo "  DC_FS       Way to pass yml file to 'docker stack deploy' [ conf | file ]; default: conf"
  echo
  echo "Flags"
  echo "  -E          Only show (echo) the command without executing it"
  echo "  -[D|P]      Override DC_ENV: D = dev; P = prod"
  echo "  -[C|S]      Override DC_MODE: C = conf; S = stack"
  echo "  -F          Pass yml files directly to 'docker stack deploy' instead of using docker-compose config. Same as DC_FS"
  echo
  echo "Services:"
  find services/ -maxdepth 1 -type d | sed 1d | sed "s/services\//  /g"
  echo
  echo "Options, Commands, Args"
  echo "  See the same section for docker-compose or docker stack"
  echo "docker-compose <=> docker stack commands map"
  echo " dc.sh     |  docker-compose  |  docker stack"
  echo "-----------------------------------------------"
  echo " up        |  up              |  deploy"
  echo " start     |  start           |  deploy"
  echo " config    |  config          |  NONE: fall back to docker-compose"
  echo " build     |  build           |  NONE: fall back to docker-compose"
  echo " <command> |  <command>       |  <command>"
  echo
  echo "Examples:"
  echo "  ./dc.sh hello-world up"
  echo
  echo "  ./dc.sh -P hello-world up"
  echo "  or same as above with env variable:"
  echo "  DC_ENV=prod ./dc.sh hello-world up"
  echo "  if the DC_ENV is set ('export DC_ENV=prod') then this does the same as above:"
  echo "  ./dc.sh hello-world up"
  echo
  echo "  DC_ENV=prod DC_MODE=compose ./dc.sh -E hello-world up"
  echo
}

# *** ARGUMENTS ***
if [ $# -eq 0 ]; then
  show_usage
  exit
else
  cmd_echo=0
  while getopts "EDPCSF" opt; do
    case $opt in
    E) cmd_echo=1 ;;
    D) dc_env="dev" ;;
    P) dc_env="prod" ;;
    C) dc_mode="compose" ;;
    S) dc_mode="stack" ;;
    F) dc_fs="file" ;;
    \?) show_usage; exit ;;
    esac
  done
  shift $(expr $OPTIND - 1)
  svc=$1
  shift
  # check if the service directory exists
  if [ ! -d "services/$svc" ]; then
    echo "$0 [error] '$svc' service could not be found in services (services/$svc)" >&2
    exit 1
  else 
    if [ ! -f "services/$svc/docker-compose.base.yml" ]; then
      echo "$0 [error] the docker-compose.base.yml is missing in services/$svc/" >&2
      exit 1
    fi
    if [ ! -f "services/$svc/docker-compose.dev.yml" ]; then
      echo "$0 [error] the docker-compose.base.yml is missing in services/$svc/" >&2
      exit 1
    fi
    if [ ! -f "services/$svc/docker-compose.prod.yml" ]; then
      echo "$0 [error] the docker-compose.base.yml is missing in services/$svc/" >&2
      exit 1
    fi
  fi
fi
# run main process
main "$@"
exit
