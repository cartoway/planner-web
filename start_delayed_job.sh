#!/bin/bash

# Variable DELAYED_JOB_ARGS contains the arguments for delayed jobs for, e.g. defining queues and worker pools.
DELAYED_JOB_ARGS="$@"

# function that is called when the docker container should stop. It stops the delayed job processes
_term() {
  echo "Caught SIGTERM signal! Stopping delayed jobs !"
  # unbind traps
  trap - SIGTERM
  trap - TERM
  trap - SIGINT
  trap - INT
  # end delayed jobs
  bundle exec "./bin/delayed_job ${DELAYED_JOB_ARGS} stop"

  exit
}

# register handler for selected signals
trap _term SIGTERM
trap _term TERM
trap _term INT
trap _term SIGINT

echo "Starting delayed jobs ... with ARGs \"${DELAYED_JOB_ARGS}\""

# restart delayed jobs on script execution
rm -f delayed_job_logs && mkfifo delayed_job_logs
cat delayed_job_logs &
bundle exec "./bin/delayed_job ${DELAYED_JOB_ARGS} restart"

echo "Finished starting delayed jobs... Waiting for SIGTERM / CTRL C"

# sleep forever until exit
while true; do sleep 86400; done
