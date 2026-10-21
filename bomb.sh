#!/bin/sh
# An authentic (recursive, self-replicating) fork bomb, with one change that
# makes it *observable*: each process sleeps instead of spinning, so we can watch
# the process count climb and then flatten against whatever limit is in force.
# This is only ever run INSIDE a throwaway container, so its blast radius is the
# container's PID namespace -- the host is never at risk.
bomb() { bomb & bomb & sleep "${BOMB_SLEEP:-8}"; }
bomb
