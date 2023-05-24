#!/bin/bash

# Script filename
SCRIPT_NAME="$(basename "$0")"

## Global variables

VERBOSE=0                     # Controls how noisy this script should be
ZRAM_DEVICE=/dev/zram0        # Default ZRAM device
ZRAM_TMPROOT=/tmp/zramroot    # ZRAM rootfs mount point
ZRAM_DISKSIZE=$((1024+512))M  # ZRAM rootfs size (defaults to 1.5G)
ZRAM_COMP_ALGORITHM=lz4       # ZRAM compression algorithm

## {{{ error()
function error()
{
  echo >&2 "$SCRIPT_NAME: error:" "$@"
}
## }}}

## {{{ warn()
function warn()
{
  echo >&2 "$SCRIPT_NAME: warning:" "$@"
}
## }}}

## {{{ info()
function info()
{
  [[ $VERBOSE -gt 0 ]] && echo ">>" "$@"
}
## }}}

## {{{ die()
function die()
{
  error "$@"
  exit 1
}
## }}}

## {{{ running_services()
function running_services()
{
  systemctl list-units \
    |grep '^.*\.service[[:space:]]\+loaded.*running' \
    |awk '{print $1}'
}
## }}}

## {{{ stop_service()
function stop_service()
{
  if [[ $# -ne 1 ]]
  then
    echo >&2 "error: stop_service() requires exactly 1 rgument (got $#)"
    exit 1
  fi

  local s="$1"
  info "Stopping $s"
  systemctl stop "$s"

  local rc=$?
  [[ $rc -ne 0 ]] && warn "$s: systemctl stop failed"
}
## }}}

## {{{ restart_service()
function restart_service()
{
  if [[ $# -ne 1 ]]
  then
    echo >&2 "error: restart_service() requires exactly 1 rgument (got $#)"
    exit 1
  fi

  info "Restarting $s"
  systemctl restart $s || warn "$s: systemctl restart failed"
}
## }}}

## {{{ ignore_service()
function ignore_service()
{
  if [[ $# -ne 1 ]]
  then
    echo >&2 "error: ignore_service() requires exactly 1 rgument (got $#)"
    exit 1
  fi

  local s="$1"
  case "$(basename $s .service)" in
    dbus|rsyslog|ssh|systemd-*|*tty*@*tty*|user@*)  return 0 ;;
    *)                                              return 1 ;;
  esac
}
## }}}

## {{{ stop_services()
function stop_services()
{
  info "Stopping services"

  for s in $(running_services)
  do
    ignore_service "$s" && continue
    stop_service "$s"
  done
}
## }}}

## {{{ restart_services()
function restart_services()
{
  info "Re-executing systemd"
  systemctl daemon-reexec || die "systemctl daemon-reexec failed"

  info "Restarting networking.service"
  service networking restart || warn "networking: service restart failed"

  info "Restarting services"
  for s in $(running_services)
  do
    restart_service "$s"
  done
}
## }}}

## {{{ zram_rootfs_config()
function zram_rootfs_config()
{
  info "Configuring $ZRAM_DEVICE"

  modprobe zram || die "zram: modprobe failed"

  echo $ZRAM_COMP_ALGORITHM > /sys/block/zram0/comp_algorithm \
    || die "/sys/block/zram0/comp_algorithm: echo failed"
  echo $ZRAM_DISKSIZE > /sys/block/zram0/disksize \
    || die "/sys/block/zram0/disksize: echo failed"
}
## }}}

## {{{ zram_rootfs_format()
function zram_rootfs_format()
{
  info "Creating ext4 filesystem on $ZRAM_DEVICE"

  if [[ $VERBOSE -gt 1 ]]
  then
    mkfs -t ext4 $ZRAM_DEVICE || die "$ZRAM_DEVICE: mkfs.ext4 failed"
  else
    local out="$(mkfs -t ext4 $ZRAM_DEVICE 2>&1)"
    [[ $? -eq 0 ]] && return
    echo >&2 "$out"
    die "$ZRAM_DEVICE: mkfs.ext4 failed"
  fi
}
## }}}

## {{{ zram_rootfs_mount()
function zram_rootfs_mount()
{
  mkdir $ZRAM_TMPROOT || die "$ZRAM_TMPROOT: mkdir failed"
  mount $ZRAM_DEVICE $ZRAM_TMPROOT || die "$ZRAM_TMPROOT: mount failed"
  mkdir $ZRAM_TMPROOT/{proc,sys,dev,run,usr,var,tmp,oldroot}
}
## }}}

## {{{ zram_rootfs_pivot()
function zram_rootfs_pivot()
{
  info "Switching / to $ZRAM_TMPROOT"

  mount --make-rprivate / || die "/: mount --make-rprivate failed"
  pivot_root $ZRAM_TMPROOT $ZRAM_TMPROOT/oldroot \
    || die "$ZRAM_TMPROOT: pivot_root failed"

  local d
  for d in dev proc sys run
  do
    mount --move /oldroot/$d /$d || die "/$d: mount --move failed"
  done
}
## }}}

## {{{ zram_rootfs_migrate()
function zram_rootfs_migrate()
{
  info "Migrating / to $ZRAM_TMPROOT"

  zram_rootfs_config
  zram_rootfs_format
  zram_rootfs_mount

  info "Copying / to $ZRAM_TMPROOT"
  cd /
  cp -ax . $ZRAM_TMPROOT/ || "$ZRAM_TMPROOT: cp failed"

  zram_rootfs_pivot
}
## }}}

## {{{ check_deps()
function check_deps()
{
  [[ -z $(type -P systemd) ]] \
    && die "this script works only on systemd-based systems"

  local dep
  for dep in systemctl service
  do
    [[ -z $(type -P $dep) ]] && die "dependency '$dep' not found in PATH"
  done
}
## }}}

## {{{ usage()
function usage()
{
  local st=1
  [[ -n $1 ]] && st="$1"

  echo >&2 "Usage: $SCRIPT_NAME [options]"
  exit $st
}
## }}}

## {{{ main()
function main()
{
  local opts=()
  local args=()

  while [[ $# -gt 0 ]]
  do
    local arg="$1"
    shift

    case "$arg" in
      --) break 2;;
      -*) opts+=("$arg");;
      *)
        set -- "$arg" "$@"
        break 2
        ;;
    esac
  done

  [[ $# -gt 0 ]] && args+=("$@")

  local opt
  for opt in "${opts[@]}"
  do
    case "$opt" in
      -v|--verbose)  ((VERBOSE++)) ;;
      *)             die "invalid option '$opt'" ;;
    esac
  done

  # Ensure we're running on a systemd-based system
  check_deps

  stop_services
  zram_rootfs_migrate
  restart_services

  return 0
}
## }}}

main "$@"
exit $?

##
# vim: ts=2 sw=2 et fdm=marker :
##
