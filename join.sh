function join { local IFS="$1"; shift; echo "$*"; }
join "$@"
