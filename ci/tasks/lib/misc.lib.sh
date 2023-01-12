run::logged() {
  local msg="$1" ; shift
  local rc=0

  echo >&2 "## ---- ${msg}"
  "$@" || rc=$?
  echo >&2 "## ----"
  echo >&2

  return $rc
}
