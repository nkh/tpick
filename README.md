# tpick

Pick one or more items from a list, it uses fzf or a numbered-list fallback when fzf is absent or disabled with `--no-fzf`.

You can also display a preview when fzf is used.

It reads *items* from stdin (or a file) and writes the **selected line(s)** to stdout.

## items format

`text<TAB>text<TAB>...`

By convention the first text field is a key and the rest are values. The key is not displayed (see option --nth).

## Usage

```
tpick [--prompt STR] [--preview TMPL] [--multi] [--header STR] [--nth FIELDSET] [FZF_OPTS...] [ITEMS_FILE]

  ... | tpick [opts]        # read items from stdin (preferred)
  tpick [opts] -            # read items from stdin (explicit)
  tpick [opts] ITEMS_FILE   # read items from a file 
```

| Option      | Meaning                                                                                                                        |
| ---         | ---                                                                                                                            |
| `--prompt`  | Prompt string (default `select`).                                                                                              |
| `--preview` | A command template fzf runs per item. `{1}`, `{2}`, `{3}`, … are the item's 1st, 2nd, 3rd, … TAB-delimited fields.             |
| `--multi`   | Allow several selections (requires fzf).                                                                                       |
| `--header`  | A header line above the list.                                                                                                  |
| `--nth`     | Which TAB fields fzf *displays*, fzf `--with-nth` syntax (default `2..`.                                                       |
| `--popup`   | Float the picker in a tmux popup (`fzf-tmux -p`). Requires fzf.                                                                |
| `--no-fzf`  | Refuse fzf even when installed, forcing the numbered-list fallback. `--multi`/`--popup`/forwarded fzf options exit 2 under it. |

`--popup` runs the picker via `fzf-tmux -p` (a centered floating popup) when
inside a tmux session that has `fzf-tmux`; outside tmux, or without `fzf-tmux`,
it prints a warning and falls back to inline fzf. The numbered-list fallback
can't serve it, so `--popup` without fzf exits 2.

Any **other** `--option` is forwarded to fzf verbatim when fzf is available
(e.g. `--reverse`, `--cycle`, `--border`, `--height=10`, `--pointer=▶`), so you
can tune fzf's UI without tpick getting in the way. Value options must
use the `--opt=value` form; the items file is then unambiguously the first bare
argument. With fzf absent, extra options are rejected (exit 2).

### Exit codes

| Code | Meaning                                                                                                             |
| ---  | ---                                                                                                                 |
| 0    | A selection was made (stdout is non-empty).                                                                         |
| 1    | Cancelled, or no items.                                                                                             |
| 2    | Bad usage, `--multi`/`--popup`/extra options without fzf (absent or `--no-fzf`), or no items on an interactive tty. |

## How previews work

The `--preview` value is a shell command fzf runs once per highlighted item
(panes render in a 60%-wide wrapped pane on the right). fzf splits each item on
TAB and substitutes `{1}`, `{2}`, `{3}`, … with the first, second, third, …
field — so an item with more than two fields can carry data that is only shown
in the preview (a date, a path, a tag). `{1}` is conventionally the key and
`{2}` the display, but tpick itself does not single any field out; that
naming is just the usual convention. Previews only render when fzf is present;
under the numbered-list fallback `--preview` is ignored.

Three things to keep in mind when writing templates:

- `{1}`, `{2}`, `{3}`, … are substituted **single-quoted** by fzf — a value
  like `my file` becomes `'my file'`, already one safe shell argument. Use
  `{n}` **bare** as a command argument: `--preview 'bat {1}'` runs
  `bat 'my file'`. Do **not** wrap `{n}` in your own quotes — `bat "{1}"`
  makes fzf emit `bat "'my file'"`, and bat then looks for a file literally
  named `'my file'` (quotes included). The same silently breaks any pattern
  that embeds `{n}` inside quotes: `grep "^Host {1}$"` turns into
  `grep "^Host 'host'$"`, which can never match, so the preview stays blank
  even though the command works when run by hand. To embed `{n}` in a quoted
  pattern, split the quoting around it — `grep "^Host "{1}"$"` — so fzf's
  single quotes fall outside your own and the shell glues the pieces back into
  `^Host host$`.
- **Only** `{n}` tokens (a number in braces) are replaced. Other braces such as
  a tmux `#{pane_id}` pass through untouched, so tmux format strings are safe in
  preview templates.
- What fzf *displays* in the list is set by `--nth` (default `2..`, i.e. every
  field from the second onward); `{n}` in the preview is independent of `--nth`
  and can reference a field that is not shown in the list.

## Examples

Every example follows the same shape: **pipe a `key<TAB>display` list into
`tpick`, then act on the line it prints.** tpick returns the whole
line (all TAB fields), so each example extracts the key — the first field —
with `${line%%$'\t'*}` before using it (for several selections, loop and strip
each line). A bare `key` (no TAB) is fine when the key is also the thing you
want to display; it comes back as `key<TAB>key`, and the strip yields `key`.

### Pick a tmux pane (the reason it was written)

The key is the stable tmux pane id (`%N`, unique across the whole server), so
`tmux capture-pane -t {1}` and `tmux select-pane -t {1}` both target exactly
the pane you highlighted.

```sh
# every pane, in every session, with a live capture of its screen
line=$(tmux list-panes -a -F $'#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}  #{pane_current_command}' \
  | tpick --prompt 'pane' --header 'all sessions' \
                --preview 'tmux capture-pane -p -e -t {1}')
pane=${line%%$'\t'*}                                # the key is field 1
[[ -n "$pane" ]] && tmux select-pane -t "$pane"     # jump to it
```

Scope the list by session instead of `-a` (all) when you only want a corner of
the server:

```sh
# only the current (attached) session
tmux list-panes -s -F $'#{pane_id}\t#{window_index}.#{pane_index}  #{pane_current_command}' \
  | tpick --prompt 'pane' --preview 'tmux capture-pane -p -e -t {1}'

# one named session, e.g. the "dev" session
tmux list-panes -t dev -F $'#{pane_id}\t#{window_index}.#{pane_index}  #{pane_current_command}' \
  | tpick --prompt 'pane' --preview 'tmux capture-pane -p -e -t {1}'
```

Mark several panes at once and kill them — `--multi` turns the list into a
checkbox picker (requires fzf):

```sh
tmux list-panes -a -F $'#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}  #{pane_current_command}' \
  | tpick --multi --prompt 'kill' --header 'mark panes to reap' \
                --preview 'tmux capture-pane -p -t {1}' \
  | while IFS= read -r line; do p=${line%%$'\t'*}; tmux kill-pane -t "$p"; done
```

Pick a **window** instead of a pane — the key is `session:window`, the preview
captures that window's active pane:

```sh
win=$(tmux list-windows -a -F $'#{session_name}:#{window_index}\t#{session_name}:#{window_index}  #{window_name} (#{window_panes} panes)' \
  | tpick --prompt 'window' --preview 'tmux capture-pane -p -e -t {1}')
win=${win%%$'\t'*}
[[ -n "$win" ]] && tmux select-window -t "$win"
```

A reusable "jump to any pane, anywhere" helper you can bind to a key — no temp
file, no cleanup, just a pipe:

```sh
pp-pane() {
  local line pane
  line=$(tmux list-panes -a -F $'#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}  #{pane_current_command}' \
        | tpick --prompt 'pane' --header 'all sessions' \
                      --preview 'tmux capture-pane -p -e -t {1}')
  pane=${line%%$'\t'*}
  [[ -n "$pane" ]] && tmux select-pane -t "$pane"
}
```

### Beyond tmux — twelve more uses

Anywhere you can emit `key<TAB>display` (or bare `key`) lines, `tpick`
gives you a previewing, fallback-safe menu.

**1. Switch git branch** — preview the last few commits on each branch:

```sh
line="$(git branch --format='%(refname:short)' \
  | tpick --prompt 'branch' --preview 'git log --oneline --color=always --stat -8 {1}')"
git checkout "${line%%$'\t'*}"
```

**2. Open a file in `$EDITOR`** — `fd` lists paths, `bat` previews them:

```sh
line=$(fd --type f \
  | tpick --prompt 'open' --preview 'bat --color=always --style=numbers {1} 2>/dev/null || sed -n "1,40p" {1}')
f=${line%%$'\t'*}
[[ -n "$f" ]] && "${EDITOR:-vi}" "$f"
```

**3. Signal a process** — key is the PID, preview its full command line:

```sh
line=$(ps -eo pid=,comm= --sort=-comm | awk '{print $1"\t"$2}' \
  | tpick --prompt 'signal' --preview 'ps -o pid,ppid,user,etime,args -p {1}')
pid=${line%%$'\t'*}
[[ -n "$pid" ]] && kill "$pid"
```

**4. Shell into a Docker container** — key is the container id, preview its
recent logs (docker interprets `\t` in `--format`):

```sh
line=$(docker ps --format '{{.ID}}\t{{.Names}} ({{.Image}})' \
  | tpick --prompt 'container' --preview 'docker logs --tail 30 {1}')
cid=${line%%$'\t'*}
[[ -n "$cid" ]] && docker exec -it "$cid" sh
```

**5. SSH to a host from `~/.ssh/config`** — preview the matching config block:

```sh
line=$(awk '/^Host / && $2 !~ /[*?]/ {print $2}' ~/.ssh/config \
  | tpick --prompt 'ssh' --preview 'grep -A8 -i "^Host "{1}"$" ~/.ssh/config')
host=${line%%$'\t'*}
[[ -n "$host" ]] && ssh "$host"
```

**6. Exec into a Kubernetes pod** — preview `describe`:

```sh
line=$(kubectl get pods --no-headers -o custom-columns=NAME:.metadata.name \
  | tpick --prompt 'pod' --preview 'kubectl describe pod {1} | sed -n "1,40p"')
pod=${line%%$'\t'*}
[[ -n "$pod" ]] && kubectl exec -it "$pod" -- sh
```

**7. Run an npm script** — key is the script name, display (and preview) is the
command it runs:

```sh
line=$(jq -r '.scripts | to_entries[] | "\(.key)\t\(.value)"' package.json \
  | tpick --prompt 'npm' --preview 'echo runs: {2}')
script=${line%%$'\t'*}
[[ -n "$script" ]] && npm run "$script"
```

**8. Run a Make target** — list every line that starts with `name:` (this skips
variable assignments and `.PHONY`), preview the recipe:

```sh
line=$(grep -E '^[A-Za-z_][A-Za-z0-9_.-]*:' Makefile | grep -v '=' | cut -d: -f1 \
  | tpick --prompt 'make' --preview 'grep -A3 "^"{1}":" Makefile')
target=${line%%$'\t'*}
[[ -n "$target" ]] && make "$target"
```

To show the `## description` as the display when your Makefile uses that
convention (and bare names otherwise), swap the `grep … cut` for this awk:

```sh
awk '/^[A-Za-z_][A-Za-z0-9_.-]*:/ && !/=/ {
  t=$0; sub(/:.*/,"",t); r=$0; sub(/^[^:]*:/,"",r); d=t
  if (match(r,/##[ \t]*/)) { d=substr(r,RSTART+RLENGTH); sub(/[ \t]*$/,"",d) }
  print t "\t" d
}' Makefile | tpick --prompt 'make' --preview 'grep -A3 "^"{1}":" Makefile'
```

**9. Jump to a ripgrep hit** — advanced: the key is `path:line`, the preview
splits it back out to show surrounding context, and the caller opens the editor
at that line:

```sh
sel=$(rg --no-heading -n --color=never 'TODO' | awk -F: '{print $1":"$2"\t"$0}' \
  | tpick --prompt 'jump' --preview \
    'l=$(echo {1}|cut -d: -f2); sed -n "$((l-3)),$((l+3))p" "$(echo {1}|cut -d: -f1)"')
[[ -n "$sel" ]] && { key=${sel%%$'\t'*}; f=${key%%:*}; l=${key#*:}; "${EDITOR:-vi}" "+$l" "$f"; }
```

**10. Change directory** — `cd` runs in the parent shell because the command
substitution is evaluated there, while `tpick` runs in the subshell:

```sh
line="$(fd --type d --max-depth 3 \
  | tpick --prompt 'cd' --preview 'ls -la {1} 2>/dev/null | head -25')"
cd "${line%%$'\t'*}"
```

**11. Tail a systemd service** — key is the unit, preview its status plus recent
journal:

```sh
line=$(systemctl list-units --type=service --no-legend --plain | awk '{print $1"\t"$4}' \
  | tpick --prompt 'unit' \
    --preview 'systemctl status {1} --no-pager | head -20; echo ---; journalctl -u {1} -n 15 --no-pager')
unit=${line%%$'\t'*}
[[ -n "$unit" ]] && journalctl -u "$unit" -f
```

**12. Review a modified file** — `git ls-files -m` lists tracked files with
uncommitted changes, preview the diff:

```sh
line=$(git ls-files -m \
  | tpick --prompt 'diff' --preview 'git diff --color=always -- {1} | head -40')
f=${line%%$'\t'*}
[[ -n "$f" ]] && git diff -- "$f"
```

### More than two fields — display, preview, and the whole line back

Every item may carry more than two TAB-separated fields. Field 1 is the key (by
convention); fields from the second onward are the display; and any further
field is reachable in the preview as `{3}`, `{4}`, … but is **not** shown in the
list unless `--nth` says so. The whole line — all fields — comes back on stdout,
so the caller reads field 1 as the key and any other field it cares about.

```sh
# pick a release: key / two-column display / a date shown only in the preview
line=$(printf 'v1.2.3\trelease 1.2.3\ttagged 2024-01-15\nv1.3.0\trelease 1.3.0\ttagged 2024-03-20\n' \
  | tpick --nth 2,3 --prompt 'release' \
                --preview 'echo {1} was {3}')
rel=${line%%$'\t'*}                       # v1.3.0              — field 1 (the key)
date=${line#*$'\t'}; date=${date#*$'\t'} # tagged 2024-03-20   — field 3
echo "checked out $rel ($date)"
```

- `--nth 2,3` makes the list show fields 2 *and* 3 (`release 1.3.0  tagged
  2024-03-20`). The default is `2..` (every field from the second on); `--nth 2`
  shows only the display column.
- `{3}` in the preview reads the date even when `--nth` hides it — the preview's
  `{n}` and the list's `--nth` are independent.
- The returned `$line` is the whole `v1.3.0\trelease 1.3.0\ttagged 2024-03-20`;
  `${line%%$'\t'*}` gives the key, and peeling tabs gives later fields.

### Reading from a file


```sh
printf 'a\talpha\nb\tbeta\n' > /tmp/items
tpick --prompt 'pick' /tmp/items          # fzf if available, else numbered
tpick --preview 'cat {1}.txt' /tmp/items  # live preview
tpick --multi /tmp/items                  # mark several
tpick --no-fzf --prompt 'pick' /tmp/items # force the numbered list even with fzf
```

Every example degrades gracefully: if fzf is not installed, the `--preview`
template is ignored and you get a numbered list reading a single choice from
stdin (file mode) or `/dev/tty` (pipe mode) — single-select only, since
`--multi` exits with code 2. Pass `--no-fzf` to take this path deliberately
even when fzf is installed. When fzf *is* installed (and `--no-fzf` is not set)
it is the only picker used: pressing Esc or Ctrl-C cancels and exits immediately
(code 1) — it never falls through to the numbered list. A SIGINT/SIGTERM/SIGHUP
at any point (for example while the numbered-list fallback is waiting for your
choice) removes the internal temp file and exits 128+signal, so nothing leaks
under `kill`.

## Install

```sh
mkdir -p ~/.local/bin
cp tpick ~/.local/bin/
chmod +x ~/.local/bin/tpick
```

Make sure `~/.local/bin` is on your `PATH`. fzf is optional but recommended
(without it you lose previews and multi-select).

## Tests

```sh
make test
```

Tests use a fake `fzf` (see `test/lib/fake-fzf.sh`) so the fzf code path is
exercised without requiring fzf to be installed; the numbered-list fallback is
tested directly, and step `06-stdin` covers reading items from a pipe. Steps
`07-extras` (options forwarded to fzf), `08-popup` (a fake `fzf-tmux` verifies
the popup path), `09-signal` (a SIGTERM/SIGINT mid-run must remove the temp
file and exit 128+signal), and `11-multifield` (items with more than two
fields: the whole line comes back, `{3}` is reachable in the preview, `--nth`
controls the displayed columns) round out the suite.

## License

GPL 3 or Artistic License 2
