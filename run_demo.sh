#!/usr/bin/env bash
# Safe demonstration of how a fork bomb is contained by two independent limits:
#   1. a cgroup v2 pids.max cap  (Docker exposes it as --pids-limit)
#   2. a per-user RLIMIT_NPROC   (Docker exposes it as --ulimit nproc=...)
# The bomb only ever runs inside a one-shot container, so the host is isolated by
# the container's PID namespace regardless of which limit we are testing.
# We sample the process count with `docker stats` (runs on the HOST), so sampling
# never needs to fork a process inside the saturated container.
set -u
IMG=forkdemo:latest

sample() {               # $1 = container name
  echo "  live process count inside the container (sampled from the host):"
  for _ in 1 2 3 4 5 6; do
    n=$(docker stats --no-stream --format '{{.PIDs}}' "$1" 2>/dev/null)
    printf '    %s procs\n' "${n:-?}"
  done
}

demo() {                 # $1 = label  $2.. = docker run flags
  label=$1; shift
  name="fb_$RANDOM"
  echo "=============================================================="
  echo "$label"
  echo "  docker run $*"
  docker run -d --rm --name "$name" "$@" "$IMG" \
    sh -c 'BOMB_SLEEP=12 sh /bomb.sh 2>/tmp/err; sleep 25' >/dev/null
  sample "$name"
  docker rm -f "$name" >/dev/null 2>&1
  echo "  -> plateaus at the cap instead of growing without bound."
  echo "  host untouched: processes owned by me on the HOST = $(ps -u "$(id -u)" --no-headers | wc -l)"
  echo
}

echo "Host (never modified by this demo):"
echo "  ulimit -u (max user processes) = $(ulimit -u)"
echo "  cgroup version = $(stat -fc %T /sys/fs/cgroup)"
echo
echo "A fork bomb is: bomb(){ bomb & bomb & ...; }; bomb  -- each call spawns two"
echo "more, so with no limit the process count doubles until the machine dies."
echo

demo "DEFENSE 1 - cgroup pids.max = 64  (--pids-limit 64)" --pids-limit 64
demo "DEFENSE 2 - RLIMIT_NPROC = 64 for a unused uid (--ulimit nproc=64, -u 4321)" \
     --pids-limit 100000 --ulimit nproc=64:64 -u 4321:4321
demo "CONTRAST - raise the cgroup cap to 400: plateaus higher, still bounded (--pids-limit 400)" --pids-limit 400
