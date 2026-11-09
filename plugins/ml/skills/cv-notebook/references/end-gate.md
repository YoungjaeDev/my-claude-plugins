# End Gate: validate the generated notebook

Two validation paths for a generated notebook, run before it is handed back. `NotebookEdit` builds cells but never runs them, so a syntax slip (an unclosed paren, a missing colon) ships silently and the user only hits it mid-run. Take the strongest path the environment allows.

1. **Execute setup + first-load cells (stronger, env-permitting)**: if `jupyter` is installed and the target env has the notebook's deps, run `jupyter nbconvert --to notebook --execute --ExecutePreprocessor.timeout=120 <notebook>` on a temp copy sliced down to the GPU-check, Setup and first Data cells, so no full training run starts. This catches import and runtime errors that py_compile cannot.
2. **py_compile the code cells (deterministic fallback, always runs)**: no packages or GPU needed. Extract each code cell, strip IPython magics and shell escapes (`!…`, `%…`), and `py_compile` the cells in order. On the first failure, report "unverified beyond cell N": cells 1..N-1 are syntactically sound, and N is where it breaks.

## py_compile block

```bash
NB="notebook.ipynb"           # the generated notebook
tmp=$(mktemp -d)
jq -r '.cells[] | select(.cell_type=="code")
       | (.source | if type=="array" then join("") else . end) | @base64' "$NB" > "$tmp/cells.b64"
n=0; status=pass
while IFS= read -r b64; do
  [ -n "$b64" ] || continue
  n=$((n+1))
  printf '%s' "$b64" | base64 -d \
    | sed 's/^[[:space:]]*[!%].*/pass  # magic stripped/' > "$tmp/cell_$n.py"
  if ! python3 -m py_compile "$tmp/cell_$n.py" 2>"$tmp/err"; then
    echo "py_compile FAIL at code cell $n — unverified beyond cell $n:"; sed 's/^/    /' "$tmp/err"
    status=fail; break
  fi
done < "$tmp/cells.b64"
[ "$status" = pass ] && echo "py_compile: all $n code cell(s) syntactically valid"
rm -rf "$tmp"
```

Fix the reported cell and re-run until it passes. If only the nbconvert path failed on a missing dependency, say so explicitly ("unverified beyond cell N, env lacks `<pkg>`") rather than claiming the notebook runs.
