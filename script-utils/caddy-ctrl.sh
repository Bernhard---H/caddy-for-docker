#!/usr/bin/env bash

SECONDS=0

function errexit() {
  local err=$?
  set +o xtrace
  local code="${1:-1}"
  echo "Error in ${BASH_SOURCE[1]}:${BASH_LINENO[0]}. '${BASH_COMMAND}' exited with status $err" >&2
  # Print out the stack trace described by $function_stack  
  if [ ${#FUNCNAME[@]} -gt 2 ]
  then
    echo "Call tree:" >&2
    for ((i=1;i<${#FUNCNAME[@]}-1;i++))
    do
      echo " $i: ${BASH_SOURCE[$i+1]}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(...)" >&2
    done
  fi
  echo "Exiting with status ${code}" >&2
  exit "${code}"
}

# trap ERR to provide an error handler whenever a command exits nonzero
#  this is a more verbose version of set -o errexit
trap 'errexit' ERR
# setting errtrace allows our ERR trap handler to be propagated to functions,
#  expansions and subshells
set -o errtrace

PROGPATH=`dirname $0`
SCRIPT_NAME="${0:-caddy-ctrl.sh}"

print_usage() {
  echo "
Usage: ${SCRIPT_NAME} --help
Usage: ${SCRIPT_NAME} <COMMAND>

Description:
============

  CLI tool for controlling the caddy container.

Command-Groups:
===============

  * docker
  * git
  * site

Commands:
=========

  * d[ocker] logs [{-f|--follow}]
  * d[ocker] start
  * d[ocker] stop
  * d[ocker] restart
  * d[ocker] update

  * g[it] update

  * s[ite] enable <filename>
  * s[ite] disable <filename>

Global Flags:
=============

  -h | --help
  -v                  may be used mulitple times for increased logging volume
  --log {error|warn|info|debug|trace}

"
}
#################################################

# from Syslog spec: https://www.rfc-editor.org/rfc/rfc5424#section-6.2.1
declare -rA LOG_LEVEL_MAP=( ["error"]="3" ["warn"]="4" ["info"]="6" ["debug"]="7" ["trace"]="8" )
declare -r ERROR="error"
declare -r WARN="warn"
declare -r INFO="info"
declare -r DEBUG="debug"
declare -r TRACE="trace"
lastErrorCode=0
activeLogLevel=4

function log()
{
  local -r level="${1}"
  local -r levelNr="${LOG_LEVEL_MAP[${1}]}"
  local -r msg="${2}"

  if (( levelNr <= activeLogLevel )); then
    echo "[${level^^}] $(date +'%Y-%m-%d %H:%M:%S.%3N') | $(printf "${msg}" "${@:3}")"
  fi
}

function setError()
{
  if [[ "$lastErrorCode" -eq 0 ]]; then
    lastErrorCode="${1:-${ERROR_ERR_UNKNOWN}}"
  fi
  log $ERROR "program state changed to NOT_OK with code: $1  current exit code: $lastErrorCode"
}

function endScript()
{
  local code="${1:-0}"

  if [[ "$code" -eq 0 ]]; then
    code=$lastErrorCode
  fi
  if [[ "$code" -eq 0 ]]; then
    log "++OK++" "Execution result: OK"
    exit 0
  fi

  log "-ERROR-" "Execution failed with code: ${code}"
  exit "$code"
}

#################################################

printRunTime() {
  echo "current runtime: $(date -d "@$SECONDS" +"$(( $SECONDS/3600/24 )) days %H hours %M minutes %S seconds")"
}

pettyPrintBytes() {
  numfmt --to=iec-i --suffix=B --format="%3f" "$1"
}

# Make sure the correct number of command line
# arguments have been supplied
if [ $# -lt 1 ]; then
  log $ERROR "invalid number of arguments have been supplied: $#"
  print_usage
  endScript 1
fi

# parseDockerFlags() {
#   while [ -z "$commandName" ]; do
#     shiftCount=1
#     case "${1,,}" in
#       h | help)
#         print_usage
#         endScript
#         ;;
#       logs)
#         commandName="logs"
#         ;;
#       start)
#         commandName="start"
#         ;;
#       stop)
#         commandName="stop"
#         ;;
#       restart)
#         commandName="restart"
#         ;;
#       update)
#         commandName="update"
#         ;;
#       *)
#         parseGlobalFlags "$@"
#         shiftCount="$?"
#         if (( shiftCount <= 0 )); then
#           log $ERROR "Unknown argument: $1"
#           print_usage
#           endScript 1
#         fi
#         ;;
#     esac
#     if (( 0 < shiftCount )); then
#       shift $shiftCount
#     fi
#   done
# }

# while [ -z "$commandGroup" ]; do
#   shiftCount=1
#   case "${1,,}" in
#     h | help)
#       print_usage
#       endScript
#       ;;
#     d | docker)
#       commandGroup="docker"
#       parseDockerFlags "$@"
#       ;;
#     g | git)
#       commandGroup="git"
#       parseGitFlags "$@"
#       ;;
#     s | site)
#       commandGroup="site"
#       parseSiteFlags "$@"
#       ;;
#     *)
#       parseGlobalFlags "$@"
#       shiftCount="$?"
#       if (( shiftCount <= 0 )); then
#         log $ERROR "Unknown argument: $1"
#         print_usage
#         endScript 1
#       fi
#       ;;
#   esac
#   if (( 0 < shiftCount )); then
#     shift $shiftCount
#   fi
# done


#####################################################################
# GNU GetOpt parsing                                                #
#####################################################################

# general purpos constants:
declare -r RETURN_TRUE=0
declare -r RETURN_FALSE=1


getopt -T
if [ "$?" -ne 4 ]; then
    echo "Please ensure you have the GNU-Version of 'getopt' installed! exiting..." >&2
    exit 1
fi

# initialize config variables:
commandGroup=
commandName=


parsedArgs="$(getopt --name "${SCRIPT_NAME}" --shell "bash" --options "+vh" --longoptions "help,log:" -- "$@")"
if [ $? -ne 0 ]; then
  echo "Error while analyzing the script arguments" >&2
  exit 2
fi
eval set -- "$parsedArgs"

while (( "$#" > 0 )); do
  case "$1" in
    --help | -h)
      print_usage
      endScript
      ;;
    -v)
      ((activeLogLevel++))
      shift
      ;;
    --log)
      if [ "${LOG_LEVEL_MAP[${2}]+abc}" ]; then
        activeLogLevel="${LOG_LEVEL_MAP[${2}]}"
        return 2
      else
        log $ERROR "Unknown loglevel: $2"
        print_usage
        endScript 1
      fi
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Internal parsing error of scritp ${SCRIPT_NAME}."
      exit 3
      ;;
  esac
done


log $INFO "current active log level: ${activeLogLevel}"
return 0

#####################################################################
# Program Functions                                                 #
#####################################################################

doSourceInstall() {
    if [ $installOnSource = $RETURN_TRUE ]; then
      apt-get update && apt-get install -y zstd pv
    else
        echo "DISABLED: installation on source system"
    fi
}

doTargetInstall() {
    if [ $installOnTarget = $RETURN_TRUE ]; then
        ssh $SSH_TARGET -- "apt-get update && apt-get install -y zstd pv"
    else
        echo "DISABLED: installation on target system"
    fi
}

isBlockDevice() {
  if [ -z "${1+x}" ]; then
    return $RETURN_FALSE;
  fi
  if [ "$1" = "$SOURCE_DISK" ] || [ "$1" = "$TARGET_DISK" ]; then
    return $RETURN_TRUE;
  fi
  return $RETURN_FALSE;
}

isFileDevice() {
  if [ -z "${1+x}" ]; then
    return $RETURN_FALSE;
  fi
  if [ "$1" = "$SOURCE_FILE" ] || [ "$1" = "$TARGET_FILE" ]; then
    return $RETURN_TRUE;
  fi
  return $RETURN_FALSE;
}

getSourceSize() {
  local -r path="$1"
  local -r host="${2:-localhost}"

  local -r BLOCK_SIZE_CMD="echo \"\$(blockdev --getsize64 \"${path}\")\" | xargs"
  local -r FILE_SIZE_CMD="stat --printf=\"%s\" \"${path}\""

  local sourceSize=0
  if [ "$host" != "localhost" ]; then
    if isBlockDevice "$path"; then
      sourceSize="$(ssh "$host" -- "${BLOCK_SIZE_CMD}")"
    elif isFileDevice "$path"; then
      sourceSize="$(ssh "$host" -- "${FILE_SIZE_CMD}")"
    fi
  elif [ -b "${path}" ]; then
    sourceSize="$(eval "${BLOCK_SIZE_CMD}")"
  elif [ -f "${path}" ]; then
    sourceSize="$(eval "${FILE_SIZE_CMD}")"
  fi

  if [ "${sourceSize:-0}" -le 0 ]; then
    log $LOGERROR "Programmer error, current path is not a block-device or a file: $path"
    endScript 1
  fi
  echo $sourceSize
}

getProgressMeter() {
  local size="$1"
  local host="${2:-localhost}"

  if [ "$host" == "localhost" ]; then
    echo "pv --bytes --progress --timer --eta --rate --size=${size}"
  else
    echo "pv --interval 5 -F \"%T => %b\" --size=${size}"
  fi
}


declare -r CMD_DECOMPRESS="zstd --decompress --stdout --quiet"
CMD_READ=""
CMD_PROGRESS=""
CMD_OPT_COMPRESS="cat -"
CMD_OPT_DECOMPRESS="cat -"
CMD_CP_WRITE=""
CMD_VERIFY=""
buildCmdCopy() {
  local -r currentSource="$1"
  local -r currentTarget="${2}"
  local -r opt_currentHost="${3:-localhost}"

  local -r BLOCK_SIZE_CMD="echo \"\$(blockdev --getsize64 \"${currentSource}\")\" | xargs"
  local -r FILE_SIZE_CMD="stat --printf=\"%s\" \"${currentSource}\""

  CMD_PROGRESS=" cat - "

  local sourceSize=$(getSourceSize "$currentSource" "$opt_currentHost")

  if [ "${sourceSize:-0}" -gt 0 ]; then
    echo "working on path ${currentSource} with size: $(pettyPrintBytes "${sourceSize}")"
    CMD_PROGRESS="$(getProgressMeter "$sourceSize" "$opt_currentHost")"
  else
    log $LOGERROR "Programmer error, current path is not a block-device or a file: $currentSource"
    endScript 1
  fi

  CMD_READ="dd if=${currentSource} bs=4M status=none"
  CMD_OPT_COMPRESS="cat -"
  if isBlockDevice "$currentSource"; then
    CMD_OPT_COMPRESS="zstd --compress --threads=0 --stream-size=${sourceSize} --stdout --quiet "
  fi
  CMD_OPT_DECOMPRESS="cat -"
  if isBlockDevice "$currentTarget"; then
    CMD_OPT_DECOMPRESS="${CMD_DECOMPRESS}"
  fi
  CMD_CP_WRITE="dd of=${currentTarget} bs=4M status=none"
}

buildCmdVerify() {
  local path="$1"
  local host="${2:-localhost}"

  local -r BLOCK_SIZE_CMD="echo \"\$(blockdev --getsize64 \"${path}\")\" | xargs"
  local -r FILE_SIZE_CMD="stat --printf=\"%s\" \"${path}\""

  local sourceSize=$(getSourceSize $path $host)
  if [ "${sourceSize:-0}" -gt 0 ]; then
    echo "working on path ${path} with size: $(pettyPrintBytes "${sourceSize}")"
  else
    log $LOGERROR "Programmer error, current path is not a block-device or a file: $path"
    endScript 1
  fi

  CMD_PROGRESS="$(getProgressMeter "$sourceSize" "$host")"
  CMD_READ="dd if=${path} bs=4M status=none"
  CMD_OPT_DECOMPRESS=" cat -"
  if isFileDevice "$path"; then
    CMD_OPT_DECOMPRESS="${CMD_DECOMPRESS}"
  fi

  #CMD_VERIFY="sha256sum | xargs -0 printf 'SHA256-SUM: %s  ...  ${path} on ${host}\n'"
  CMD_VERIFY="openssl dgst -sha3-256 | xargs -l1 printf '%s\n' | tail -n1 | xargs printf 'SHA3-256 checksum: %s  ...  ${path} on ${host}\n'"
}


#####################################################################
# Main                                                              #
#####################################################################

doSourceInstall
doTargetInstall

if [ $DO_TRANSFER = $RETURN_TRUE ]; then
  echo "executing data transfer:"

  if [ ! -b "${SOURCE}" ] && [ ! -f "${SOURCE}" ]; then
    log $LOGERROR "Program Argument --source-disk XOR --source-file is required with a valid path!"
    endScript 1
  fi
  if [ -z "${TARGET}" ]; then
    log $LOGERROR "Program Argument --target-disk XOR --target-file is required!"
    endScript 1
  fi
  if [ -z "${SSH_TARGET}" ]; then
    log $LOGERROR "Program ARG --ssh is required!"
    endScript 1
  fi

  buildCmdCopy "$SOURCE" "$TARGET"
  $CMD_READ | $CMD_PROGRESS | $CMD_OPT_COMPRESS | ssh $SSH_TARGET -- "${CMD_OPT_DECOMPRESS} | ${CMD_CP_WRITE}"
  printRunTime
  echo "Transfer DONE."
else
  log $LOGINFO "SKIP: Transfer to the target System;  specify --do to actually transfer data"
fi

if [ $verify = $RETURN_TRUE ]; then
  echo "executing verification:"

  if [ -n "${SOURCE}" ]; then
    echo "hashing locally:"
    buildCmdVerify "$SOURCE"
    log $LOGINFO "$CMD_READ | $CMD_PROGRESS | $CMD_OPT_DECOMPRESS | eval \"$CMD_VERIFY\""
    $CMD_READ | $CMD_PROGRESS | $CMD_OPT_DECOMPRESS | eval "$CMD_VERIFY"
    printRunTime
  fi

  if [ -n "${TARGET}" ]; then
    echo "hashing over ssh:"
    buildCmdVerify "$TARGET" "${SSH_TARGET}"
    log $LOGINFO "$SSH_TARGET -- \"$CMD_READ | $CMD_PROGRESS | $CMD_OPT_DECOMPRESS | $CMD_VERIFY\""
    ssh $SSH_TARGET -- "$CMD_READ | $CMD_PROGRESS | $CMD_OPT_DECOMPRESS | $CMD_VERIFY"
    printRunTime
  fi

  #dd if="${SOURCE}" bs=4M status=none | pv --bytes --progress --timer --eta --rate --size=$SOURCE_SIZE | sha256sum |  xargs -0 printf 'SHA256-SUM: %s  ... ${SOURCE} on localhost'
  #ssh $SSH_TARGET -- "dd if=${TARGET} bs=4M status=none | sha256sum | xargs -0 printf 'SHA256-SUM: %s ... ${TARGET} on ${SSH_TARGET}'"
  echo "Verify DONE."
else
  log $LOGINFO "SKIP: Verification of the information;  specify --verify trigger verification calculation"
fi

printRunTime
endScript
