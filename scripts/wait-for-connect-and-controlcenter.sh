#!/bin/bash

IGNORE_CHECK_FOR_DOCKER_COMPOSE=true
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../scripts/utils.sh

IGNORE_CONNECT_STARTUP="FALSE"
IGNORE_CONTROL_CENTER_STARTUP="TRUE"
shiftconnect=0
shiftcontrolcenter=0

while getopts "h?ab" opt; do
    case "$opt" in
    h|\?)
        log "possible options -a to ignore connect startup and -b to not ignore control center"
        exit 0
        ;;
    a)  IGNORE_CONNECT_STARTUP="TRUE"
        shiftconnect=1
        ;;
    b)  IGNORE_CONTROL_CENTER_STARTUP="FALSE"
        shiftcontrolcenter=1
        ;;
    esac
done

if [ $shiftconnect -eq 1 ]
then
  shift
fi
if [ $shiftcontrolcenter -eq 1 ]
then
  shift
fi

CONNECT_CONTAINER=${1:-connect}
CONTROL_CENTER_CONTAINER=${1:-"control-center"}

if [ "${IGNORE_CONNECT_STARTUP}" == "FALSE" ]
then
  MAX_WAIT=480
  CUR_WAIT=0
  log "⌛ Waiting up to $MAX_WAIT seconds for ${CONNECT_CONTAINER} to start"
  docker container logs ${CONNECT_CONTAINER} > /tmp/out.txt 2>&1
  while [[ ! $(cat /tmp/out.txt) =~ "Finished starting connectors and tasks" ]]; do
    sleep 10
    docker container logs ${CONNECT_CONTAINER} > /tmp/out.txt 2>&1
    CUR_WAIT=$(( CUR_WAIT+10 ))
    if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
      logerror "ERROR: The logs in ${CONNECT_CONTAINER} container do not show <Finished starting connectors and tasks> after $MAX_WAIT seconds. Please troubleshoot with <docker container ps> and 'docker container logs"
      exit 1
    fi
  done
  log "🚦 ${CONNECT_CONTAINER} is started!"
fi


if [ "${IGNORE_CONTROL_CENTER_STARTUP}" == "FALSE" ]
then
  MAX_WAIT=480
  CUR_WAIT=0
  log "⌛ Waiting up to $MAX_WAIT seconds for ${CONTROL_CENTER_CONTAINER} to start"
  docker container logs ${CONTROL_CENTER_CONTAINER} > /tmp/out.txt 2>&1
  while [[ ! $(cat /tmp/out.txt) =~ "Started NetworkTrafficServerConnector" ]]; do
    sleep 10
    docker container logs ${CONTROL_CENTER_CONTAINER} > /tmp/out.txt 2>&1
    CUR_WAIT=$(( CUR_WAIT+10 ))
    if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
      logerror "ERROR: The logs in ${CONTROL_CENTER_CONTAINER} container do not show <Started NetworkTrafficServerConnector> after $MAX_WAIT seconds. Please troubleshoot with <docker container ps> and <docker container logs>"
      exit 1
    fi
  done
  log "🚦 ${CONTROL_CENTER_CONTAINER} is started!"
fi

# Verify Docker containers started
if [[ $(docker container ps) =~ "Exit 137" ]]; then
  logerror "ERROR: At least one Docker container did not start properly, see <docker container ps>. Did you remember to increase the memory available to Docker to at least 8GB (default is 2GB)"
  exit 1
fi

if [ -z "$DISABLE_KSQLDB" ]
then
  log "🔧 You can use ksqlDB with CLI using:"
  log "docker exec -i ksqldb-cli ksql http://ksqldb-server:8088"
fi
