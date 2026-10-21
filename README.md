# Fork bomb containment demo (`ulimit` + cgroups)

A **safe, controlled** demonstration of *why* a fork bomb stops being dangerous
once you put a limit on it. It never endangers the host: the bomb only ever runs
**inside a one-shot Docker container**, so its blast radius is the container's own
PID namespace. No host limits are changed and nothing needs `sudo`.

> This repo does **not** weaponize anything. The "bomb" is deliberately slowed
> down (each process sleeps) so you can *watch* the process count climb and then
> flatten against a limit, which is the whole lesson.

## What a fork bomb is

```sh
bomb() { bomb & bomb & ...; }; bomb
```

Each call spawns two more copies of itself, so the number of processes doubles
over and over. With **no limit**, it exhausts the kernel's process table in
seconds and the machine becomes unusable (often only a reboot recovers it). That
is exactly why you should never run the unbounded version — and why this demo
only runs the bounded version.

## The two defenses shown

| Defense | Kernel mechanism | How we set it here |
|---|---|---|
| **1. cgroup pids controller** | `pids.max` on the process's cgroup (cgroup v2) | `docker run --pids-limit N` |
| **2. per-user process limit** | `RLIMIT_NPROC` (`ulimit -u`) | `docker run --ulimit nproc=N:N -u <uid>` |

- **cgroups** cap *all* processes in a control group, no matter which user runs
  them. This is how systemd (`TasksMax=`) and container runtimes protect a host.
- **`RLIMIT_NPROC`** caps the number of processes a *single user id* may have.
  Note two real gotchas this demo accounts for:
  - root (and anything with `CAP_SYS_RESOURCE`) **bypasses** `RLIMIT_NPROC`, so
    the demo runs the bomb as a non-root uid.
  - `RLIMIT_NPROC` counts every process that uid owns *on the host*, so the demo
    uses an **unused uid (4321)** — otherwise it would also count your login
    shell's processes.

## Run it

Requires Docker. Builds a tiny `FROM scratch` + static busybox image (no network
pull needed).

```sh
cd img && docker build -t forkdemo:latest . && cd ..
./run_demo.sh
```

## What you should see

The process count inside the container rises and then **plateaus at the limit**
instead of growing without bound; the host process count is unchanged. Sample run
(`sample_output.txt`):

- `--pids-limit 64`  -> plateaus at ~61 processes
- `--ulimit nproc=64` (uid 4321) -> plateaus at ~55 processes
- `--pids-limit 400` -> plateaus at ~391 processes (raise the cap, raise the
  plateau — still bounded)

## Files

- `bomb.sh` — the slowed-down, observable fork bomb (only ever run in a container)
- `run_demo.sh` — builds nothing; starts contained containers, samples the PID
  count from the host via `docker stats`, and cleans up
- `img/Dockerfile` — minimal image: static busybox on `scratch`
- `sample_output.txt` — captured output of a run on this machine

## Recovering from a real fork bomb (if you ever hit one unprotected)

- A pre-set login limit saves you: `/etc/security/limits.conf` -> `*  hard  nproc 2000`.
- If you can still get a shell: `kill -STOP -1` then kill the offenders, or
  `pkill -9 bomb`.
- Systemd user slices cap this automatically via `TasksMax=`.
