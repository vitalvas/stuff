#!/usr/bin/env bash
#
# cage.sh - run suspicious commands in a maximally isolated sandbox.
#
# Zero external dependencies: uses only util-linux `unshare` and coreutils,
# which ship on a stock Ubuntu/Debian system. No bubblewrap, docker, or
# firejail required.
#
# Isolation provided (all via Linux namespaces):
#   - user      : runs as an unprivileged, mapped UID inside the cage
#   - mount     : private mount tree; host filesystem is NOT visible
#   - pid       : caged process tree cannot see or signal host processes
#   - net       : no network at all (only an isolated loopback)
#   - ipc       : separate System V IPC / POSIX message queues
#   - uts       : separate hostname ("cage")
#   - cgroup    : separate cgroup namespace view
#
# Filesystem layout inside the cage (everything is throwaway):
#   /            tmpfs (wiped on exit)
#   /usr /bin    bind-mounted READ-ONLY from host (so programs exist)
#   /lib*  /etc  bind-mounted READ-ONLY from host (libs + resolver stubs)
#   /tmp /work   writable tmpfs; /work is the working directory
#   /dev /proc   minimal, sandboxed
#
# Usage:
#   ./cage.sh                 # interactive isolated shell
#   ./cage.sh bash            # same, explicit
#   ./cage.sh ./suspicious.sh # run a script in the cage
#   ./cage.sh -- cmd arg arg  # everything after -- is the command
#
# Options:
#   -h, --help        show this help and exit
#   -v, --verbose     print the unshare invocation before running
#
# Resource limits (ulimit) applied inside the cage. Override via environment:
#   CAGE_MAX_PROCS    max processes/threads      (RLIMIT_NPROC, default 256)
#   CAGE_MAX_FILES    max open file descriptors  (RLIMIT_NOFILE, default 256)
#   CAGE_MAX_FILESIZE max file size, KB          (RLIMIT_FSIZE, default 1048576 = 1GiB)
#   CAGE_MAX_MEMORY   max virtual memory, KB     (RLIMIT_AS, default 2097152 = 2GiB)
#   CAGE_MAX_CPU      max CPU time, seconds      (RLIMIT_CPU, default 300)
#   CAGE_MAX_CORE     max core dump size, KB     (RLIMIT_CORE, default 0 = none)
# Set any of these to "unlimited" to disable that particular limit.
#
# Cgroup v2 limits (best-effort). Unlike ulimit (per-process), these cap the
# WHOLE cage as a group, defeating fork-bombs and total-memory exhaustion.
# They are applied only when a delegated, writable cgroup v2 hierarchy is
# available; otherwise they are silently skipped (use -v to see why).
# Override via environment ("unlimited"/"max" disables one):
#   CAGE_CG_MEMORY    total memory ceiling, bytes  (memory.max, default 2147483648 = 2GiB)
#   CAGE_CG_PIDS      total process/thread count   (pids.max, default 512)
#   CAGE_CG_CPU       CPU bandwidth, percent       (cpu.max, default 100 = one core)
#
# Exit status: the exit status of the caged command.

set -euo pipefail

PROG="${0##*/}"

die() {
	printf '%s: error: %s\n' "$PROG" "$*" >&2
	exit 1
}

usage() {
	sed -n '2,/^$/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
	exit "${1:-0}"
}

VERBOSE=0

# ---- resource limit defaults (override via environment) ----------------------
# Values are passed to `ulimit` inside the cage. "unlimited" disables a limit.

CAGE_MAX_PROCS="${CAGE_MAX_PROCS:-256}"
CAGE_MAX_FILES="${CAGE_MAX_FILES:-256}"
CAGE_MAX_FILESIZE="${CAGE_MAX_FILESIZE:-1048576}"
CAGE_MAX_MEMORY="${CAGE_MAX_MEMORY:-2097152}"
CAGE_MAX_CPU="${CAGE_MAX_CPU:-300}"
CAGE_MAX_CORE="${CAGE_MAX_CORE:-0}"

# ---- cgroup v2 limit defaults (best-effort, override via environment) --------
# These cap the whole cage. "unlimited"/"max" disables a given control.

CAGE_CG_MEMORY="${CAGE_CG_MEMORY:-2147483648}"
CAGE_CG_PIDS="${CAGE_CG_PIDS:-512}"
CAGE_CG_CPU="${CAGE_CG_CPU:-100}"

# ---- argument parsing --------------------------------------------------------

while [ $# -gt 0 ]; do
	case "$1" in
	-h | --help)
		usage 0
		;;
	-v | --verbose)
		VERBOSE=1
		shift
		;;
	--)
		shift
		break
		;;
	-*)
		die "unknown option: $1 (use -- to pass a command starting with -)"
		;;
	*)
		break
		;;
	esac
done

# Command to run inside the cage. Default to an interactive shell.
if [ $# -eq 0 ]; then
	set -- /bin/bash
fi

# ---- preflight checks --------------------------------------------------------

[ "$(uname -s)" = "Linux" ] || die "cage.sh only runs on Linux"

command -v unshare >/dev/null 2>&1 || die "'unshare' not found (install util-linux)"

# Unprivileged user namespaces must be enabled (default on modern Ubuntu).
if [ -r /proc/sys/kernel/unprivileged_userns_clone ]; then
	[ "$(cat /proc/sys/kernel/unprivileged_userns_clone)" = "1" ] ||
		die "unprivileged user namespaces are disabled (kernel.unprivileged_userns_clone=0)"
fi

# ---- build the in-cage setup script -----------------------------------------
#
# This runs as the new namespace's "root" (mapped to the caller). It assembles
# a throwaway root from read-only host bind mounts, then drops into /work and
# execs the requested command. Host directories are mounted read-only so a
# malicious payload cannot tamper with the real system.

# Read-only host paths to expose so that programs and their libraries resolve.
# Only present paths are mounted, keeping the cage minimal.
RO_PATHS="/usr /bin /sbin /lib /lib64 /lib32 /libx32 /etc/alternatives"

# A handful of harmless config files needed for name resolution and account
# lookups. /etc as a whole is intentionally NOT exposed.
ETC_FILES="/etc/ld.so.cache /etc/ld.so.conf /etc/nsswitch.conf /etc/passwd /etc/group /etc/localtime"

build_inner() {
	cat <<'INNER'
set -eu

NEWROOT="$(mktemp -d /tmp/cage.XXXXXX)"

# Private mount namespace root must be a mount point and private.
mount --make-rprivate / 2>/dev/null || true
mount -t tmpfs -o mode=0755,nosuid,nodev cage-root "$NEWROOT"

mkdir -p "$NEWROOT/proc" "$NEWROOT/dev" "$NEWROOT/tmp" "$NEWROOT/work" \
	"$NEWROOT/etc" "$NEWROOT/run"

# Read-only OS directories from the host.
for p in $RO_PATHS; do
	[ -e "$p" ] || continue
	tgt="$NEWROOT$p"
	mkdir -p "$tgt"
	mount --bind "$p" "$tgt"
	mount --bind -o remount,ro,nosuid "$p" "$tgt" 2>/dev/null || true
done

# Selected read-only config files.
for f in $ETC_FILES; do
	[ -e "$f" ] || continue
	tgt="$NEWROOT$f"
	mkdir -p "$(dirname "$tgt")"
	: >"$tgt" 2>/dev/null || true
	mount --bind "$f" "$tgt" 2>/dev/null || true
done

# Writable scratch space. /tmp and /work live on tmpfs and vanish on exit.
mount -t tmpfs -o nosuid,nodev,mode=1777 cage-tmp "$NEWROOT/tmp"
mount -t tmpfs -o nosuid,nodev,mode=0777 cage-work "$NEWROOT/work"

# Distinct hostname inside the UTS namespace.
hostname cage 2>/dev/null || true

# Fresh /proc for the new PID namespace.
mount -t proc -o nosuid,nodev,noexec proc "$NEWROOT/proc"

# Minimal device nodes via a tmpfs + bind from host /dev.
mount -t tmpfs -o nosuid,mode=0755 cage-dev "$NEWROOT/dev"
for d in null zero full random urandom tty; do
	[ -e "/dev/$d" ] || continue
	: >"$NEWROOT/dev/$d"
	mount --bind "/dev/$d" "$NEWROOT/dev/$d"
done
mkdir -p "$NEWROOT/dev/pts" "$NEWROOT/dev/shm"
mount -t tmpfs -o nosuid,nodev cage-shm "$NEWROOT/dev/shm"
ln -sf /proc/self/fd "$NEWROOT/dev/fd"
ln -sf /proc/self/fd/0 "$NEWROOT/dev/stdin"
ln -sf /proc/self/fd/1 "$NEWROOT/dev/stdout"
ln -sf /proc/self/fd/2 "$NEWROOT/dev/stderr"

# Apply resource limits so a runaway payload cannot exhaust the host.
# A failing ulimit (e.g. trying to raise a hard limit) is non-fatal.
# LIMITS_SNIPPET is a self-contained string so it also works in the chroot
# fallback, where the function and CAGE_* vars are not in scope.
LIMITS_SNIPPET="\
ulimit -u $CAGE_MAX_PROCS 2>/dev/null || true;\
ulimit -n $CAGE_MAX_FILES 2>/dev/null || true;\
ulimit -f $CAGE_MAX_FILESIZE 2>/dev/null || true;\
ulimit -v $CAGE_MAX_MEMORY 2>/dev/null || true;\
ulimit -t $CAGE_MAX_CPU 2>/dev/null || true;\
ulimit -c $CAGE_MAX_CORE 2>/dev/null || true;"

apply_limits() { eval "$LIMITS_SNIPPET"; }

# Pivot into the new root so the host tree is fully detached.
cd "$NEWROOT"
mkdir -p .oldroot
if pivot_root . .oldroot 2>/dev/null; then
	cd /
	umount -l /.oldroot
	rmdir /.oldroot 2>/dev/null || true
else
	# Fallback if pivot_root is unavailable: chroot is weaker but still
	# combined with the namespaces above. Limits are re-applied inside the
	# chrooted shell since they must hold for the final process.
	cd /
	exec chroot "$NEWROOT" /bin/sh -c "$LIMITS_SNIPPET"'cd /work; exec "$@"' sh "$@"
fi

apply_limits
cd /work
exec "$@"
INNER
}

# ---- launch ------------------------------------------------------------------

# unshare flags:
#   -U  user namespace        -r  map current user to root inside
#   -m  mount namespace       -p  pid namespace (--fork --mount-proc handled inside)
#   -n  network namespace (no network)
#   -i  IPC namespace         -u  UTS (hostname) namespace   -C  cgroup namespace
#   -f  fork so PID 1 is the new namespace's init
UNSHARE_FLAGS="-U -r -m -p -f -n -i -u -C"

INNER_SCRIPT="$(build_inner)"

if [ "$VERBOSE" -eq 1 ]; then
	printf '%s: unshare %s -- /bin/sh -c <setup> sh %s\n' \
		"$PROG" "$UNSHARE_FLAGS" "$*" >&2
fi

# Pass configuration into the inner shell environment.
export RO_PATHS ETC_FILES
export CAGE_MAX_PROCS CAGE_MAX_FILES CAGE_MAX_FILESIZE \
	CAGE_MAX_MEMORY CAGE_MAX_CPU CAGE_MAX_CORE

# ---- best-effort cgroup v2 setup --------------------------------------------
#
# Caps the whole cage as a group (memory.max, pids.max, cpu.max), defeating
# fork-bombs and total-memory exhaustion that per-process ulimits cannot.
#
# This must run on the host BEFORE unshare detaches us: we create a child
# cgroup, write the limits, and move our own PID into it so the unshared
# child tree inherits the membership. Every step is best-effort; any failure
# leaves CAGE_CGROUP_DIR empty and the cage runs with ulimits only.

CAGE_CGROUP_DIR=""

cg_note() {
	[ "$VERBOSE" -eq 1 ] && printf '%s: cgroup: %s\n' "$PROG" "$*" >&2
	return 0
}

setup_cgroup() {
	local root="/sys/fs/cgroup" cur parent dir ctrl have

	# Require a unified (v2) hierarchy.
	if [ ! -e "$root/cgroup.controllers" ]; then
		cg_note "v2 hierarchy not mounted at $root; skipping"
		return 0
	fi

	# Our current cgroup, e.g. "0::/user.slice/...".
	cur="$(sed -n 's/^0:://p' /proc/self/cgroup 2>/dev/null || true)"
	[ -n "$cur" ] || cur="/"
	parent="$root$cur"
	parent="${parent%/}"
	[ -d "$parent" ] || parent="$root"

	dir="$parent/cage-$$"
	if ! mkdir "$dir" 2>/dev/null; then
		cg_note "cannot create $dir (delegation unavailable); skipping"
		return 0
	fi

	# Join the child cgroup FIRST. cgroup v2 forbids a cgroup from holding
	# both processes and controller-enabled children ("no internal process"
	# rule), so the parent must be emptied of our PID before we can enable
	# controllers on its subtree. If we cannot join, limits would not apply.
	if ! echo $$ >"$dir/cgroup.procs" 2>/dev/null; then
		cg_note "cannot move into $dir; skipping"
		rmdir "$dir" 2>/dev/null || true
		return 0
	fi

	# Enable the controllers in the parent's subtree so the child exposes
	# the corresponding *.max interface files. Each is independent.
	for ctrl in memory pids cpu; do
		echo "+$ctrl" >"$parent/cgroup.subtree_control" 2>/dev/null || true
	done

	# Apply limits, skipping any disabled with unlimited/max and ignoring
	# controllers the kernel did not actually delegate (file absent).
	case "$CAGE_CG_MEMORY" in
	unlimited | max) : ;;
	*) echo "$CAGE_CG_MEMORY" >"$dir/memory.max" 2>/dev/null || true ;;
	esac
	case "$CAGE_CG_PIDS" in
	unlimited | max) : ;;
	*) echo "$CAGE_CG_PIDS" >"$dir/pids.max" 2>/dev/null || true ;;
	esac
	case "$CAGE_CG_CPU" in
	unlimited | max) : ;;
	*) echo "$((CAGE_CG_CPU * 1000)) 100000" >"$dir/cpu.max" 2>/dev/null || true ;;
	esac

	CAGE_CGROUP_DIR="$dir"
	# Report which controls actually took effect (files exist only when the
	# matching controller was successfully delegated/enabled).
	have=""
	[ -e "$dir/memory.max" ] && have="$have memory"
	[ -e "$dir/pids.max" ] && have="$have pids"
	[ -e "$dir/cpu.max" ] && have="$have cpu"
	if [ -n "$have" ]; then
		cg_note "active in $dir, controllers:$have"
	else
		cg_note "joined $dir but no controllers delegated; ulimits still apply"
	fi
}

cleanup_cgroup() {
	[ -n "$CAGE_CGROUP_DIR" ] || return 0
	# Move ourselves back to the parent so the cage dir becomes empty,
	# then remove it. Both steps are best-effort.
	local parent="${CAGE_CGROUP_DIR%/*}"
	echo $$ >"$parent/cgroup.procs" 2>/dev/null || true
	rmdir "$CAGE_CGROUP_DIR" 2>/dev/null || true
}

setup_cgroup

# shellcheck disable=SC2086
if [ -n "$CAGE_CGROUP_DIR" ]; then
	# We own a cgroup to clean up, so run unshare as a child and wait
	# rather than exec'ing (which would orphan the cgroup directory).
	# The EXIT trap guarantees cleanup even on signal or error; disabling
	# set -e around the call lets us capture the caged command's status.
	trap cleanup_cgroup EXIT INT TERM
	status=0
	set +e
	unshare $UNSHARE_FLAGS -- \
		/bin/sh -c "$INNER_SCRIPT" sh "$@"
	status=$?
	set -e
	cleanup_cgroup
	trap - EXIT INT TERM
	exit "$status"
else
	# No cgroup to manage; exec for a clean process tree.
	exec unshare $UNSHARE_FLAGS -- \
		/bin/sh -c "$INNER_SCRIPT" sh "$@"
fi
