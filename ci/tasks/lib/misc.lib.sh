run::logged() {
  local msg="$1" ; shift
  local rc=0

  echo >&2 "## ---- ${msg}"
  "$@" || rc=$?

  if [[ $rc == 0 ]] ; then
    echo >&2 "## ---- ${msg} done."
  else
    echo >&2 "## ---- ${msg} failed! (rc: $rc)"
  fi
  echo >&2

  return $rc
}
