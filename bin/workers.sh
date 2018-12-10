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


# Run a shell command on all slave hosts.
#
# Environment Variables
#
#   HAMA_GROOMS  File naming remote hosts.
#     Default is ${HAMA_CONF_DIR}/groomservers.
#   HAMA_CONF_DIR  Alternate conf dir. Default is ${HAMA_HOME}/conf.
#   HAMA_GROOM_SLEEP Seconds to sleep between spawning remote commands.
#   HAMA_SSH_OPTS Options passed to ssh when running remote commands.
##

usage="Usage: workers.sh [--config confdir] command..."

# if no args specified, show usage
if [ $# -le 0 ]; then
  echo $usage
  exit 1
fi

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

. "$bin"/termite-config.sh

# If the workers file is specified in the command line,
# then it takes precedence over the definition in 
# termite-env.sh. Save it here.
HOSTLIST=$TERMITE_WORKERS

if [ -f "${TERMITE_CONF_DIR}/termite-env.sh" ]; then
  . "${TERMITE_CONF_DIR}/termite-env.sh"
fi

if [ "$HOSTLIST" = "" ]; then
  if [ "$TERMITE_WORKERS" = "" ]; then
    export HOSTLIST="${TERMITE_CONF_DIR}/workers"
  else
    export HOSTLIST="${TERMITE_WORKERS}"
  fi
fi

for worker in `cat "$HOSTLIST"|sed  "s/#.*$//;/^$/d"`; do
 ssh $TERMITE_SSH_OPTS $worker $"${@// /\\ }" \
   2>&1 | sed "s/^/$worker: /" &
 if [ "$TERMITE_WORKER_SLEEP" != "" ]; then
   sleep $TERMITE_WORKER_SLEEP
 fi
done

wait
