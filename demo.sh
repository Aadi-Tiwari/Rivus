#!/usr/bin/env bash
# PipeTrace live demo. One command, nothing pre-baked.
#   ./demo.sh          full investigation, then open the incident board
#   ./demo.sh intake   field-note parsing only
#   ./demo.sh eval     the measured table against the random control
set -e
cd "$(dirname "$0")"
export PYTHONPATH="$PWD"
JAC="./.venv/bin/jac"

# Jac persists the graph between runs; without this a second run stacks another
# copy of the network onto root and every count silently doubles.
rm -rf .jac jac/.jac

case "${1:-demo}" in
  intake) exec $JAC run jac/intake.jac ;;
  eval)   exec $JAC run jac/evaluate.jac ;;
  *)
    $JAC run jac/main.jac
    echo
    echo "opening the incident board — every number in it came from the run above"
    open web/index.html 2>/dev/null || echo "open web/index.html"
    ;;
esac
