#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Runs a Hama command as a daemon.
#
# Environment Variables
#
#   HAMA_CONF_DIR  Alternate conf dir. Default is ${HAMA_HOME}/conf.
#   HAMA_LOG_DIR   Where log files are stored.  PWD by default.
#   HAMA_MASTER    host:path where hama code should be rsync'd from
#   HAMA_PID_DIR   The pid files are stored. /tmp by default.
#   HAMA_IDENT_STRING   A string representing this instance of hama. $USER by default
#   HAMA_NICENESS The scheduling priority for daemons. Defaults to 0.
##

usage="Usage: termite-daemon.sh [--config <conf-dir>] [--hosts hostlistfile] (start|stop) <termite-command> <args...>"

# if no args specified, show usage
if [ $# -le 1 ]; then
  echo $usage
  exit 1
fi

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

. "$bin"/termite-config.sh

# get arguments
startStop=$1
shift
command=$1
shift

termite_rotate_log ()
{
    log=$1;
    num=5;
    if [ -n "$2" ]; then
	num=$2
    fi
    if [ -f "$log" ]; then # rotate logs
	while [ $num -gt 1 ]; do
	    prev=`expr $num - 1`
	    [ -f "$log.$prev" ] && mv "$log.$prev" "$log.$num"
	    num=$prev
	done
	mv "$log" "$log.$num";
    fi
}

if [ -f "${TERMITE_CONF_DIR}/termite-env.sh" ]; then
  . "${TERMITE_CONF_DIR}/termite-env.sh"
fi

# get log directory
if [ "$TERMITE_LOG_DIR" = "" ]; then
  export TERMITE_LOG_DIR="$TERMITE_HOME/logs"
fi
mkdir -p "$TERMITE_LOG_DIR"

if [ "$TERMITE_PID_DIR" = "" ]; then
  TERMITE_PID_DIR=/tmp
fi

if [ "$TERMITE_IDENT_STRING" = "" ]; then
  export TERMITE_IDENT_STRING="$USER"
fi

# some variables
export TERMITE_LOGFILE=termite-$TERMITE_IDENT_STRING-$command-$HOSTNAME.log
export TERMITE_ROOT_LOGGER="INFO,DRFA"
log=$TERMITE_LOG_DIR/termite-$TERMITE_IDENT_STRING-$command-$HOSTNAME.out
pid=$TERMITE_PID_DIR/termite-$TERMITE_IDENT_STRING-$command.pid
# Set default scheduling priority
if [ "$TERMITE_NICENESS" = "" ]; then
    export TERMITE_NICENESS=0
fi

case $startStop in

  (start)

    mkdir -p "$TERMITE_PID_DIR"

    if [ -f $pid ]; then
      if kill -0 `cat $pid` > /dev/null 2>&1; then
        echo $command running as process `cat $pid`.  Stop it first.
        exit 1
      fi
    fi

    if [ "$TERMITE_MASTER" != "" ]; then
      echo rsync from $TERMITE_MASTER
      rsync -a -e ssh --delete --exclude=.svn --exclude='logs/*' --exclude='contrib/hod/logs/*' $TERMITE_MASTER/ "$TERMITE_HOME"
    fi

    termite_rotate_log $log
    echo starting $command, logging to $log
    cd "$TERMITE_HOME"
    nohup nice -n $TERMITE_NICENESS "$TERMITE_HOME"/bin/termite --config $TERMITE_CONF_DIR $command "$@" > "$log" 2>&1 < /dev/null &
    echo $! > $pid
    sleep 1; head "$log"
    ;;
          
  (stop)

    if [ -f $pid ]; then
      if kill -0 `cat $pid` > /dev/null 2>&1; then
        echo stopping $command
        kill `cat $pid`
      else
        echo no $command to stop
      fi
    else
      echo no $command to stop
    fi
    ;;

  (*)
    echo $usage
    exit 1
    ;;

esac
