# Sourced, not run. Windows jq.exe writes text mode, so its output ends lines in \r\n and a \r
# reaches whatever reads the pipe (sort, tr, while read): string compares then fail. Strip the \r
# on output only: --binary would also read input raw and keep the \r an autocrlf checkout puts in
# fixture files. The probe goes through tr, since Git Bash's $(...) already drops a trailing \r.
# Other platforms keep the plain jq.
case "$(command jq -n 1 2>/dev/null | tr '\r' R)" in
  *R*) jq() { command jq "$@" | tr -d '\r'; return "${PIPESTATUS[0]}"; } ;;
esac
