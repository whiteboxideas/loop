#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

for ((i=1; i<=$1; i++)); do
  result=$( claude  --dangerously-skip-permissions -p "@remotecontrol-todos.json @progress.txt @rules.txt\
  1. Find the highest-priority task from remotecontrol-todos.json. \
  2. Implement the task according summary, description and comments \
  3. Update remotecontrol-todos.json: add a new field called "completed" with value true for the completed task and add a notes field with implementation details, decisions made, or any relevant notes. \
  ONLY WORK ON A SINGLE TASK. \ 
  If all tasks in the remotecontrol-todos.json have completed: true, output <promise>COMPLETE</promise>.")

  echo "$result"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "PRD complete after $i iterations."
    exit 0
  fi
done