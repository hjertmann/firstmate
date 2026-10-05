#!/usr/bin/env bash
# Live lab: a real tmux pane whose idle zsh is renamed `zsh (kiro-cli-term)`,
# driven through the real firstmate backend, fm-control, and secondmate probe.
# Usage: kiro-shell-lab.sh <firstmate-root> [verbs...]
set -u
ROOT=$1; shift
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null || "$PWD/bin/fm-lab-home.sh" create "$LAB" >/dev/null
export TMUX_TMPDIR="$LAB/tmux"; mkdir -p "$TMUX_TMPDIR"
unset TMUX TMUX_PANE NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
export FM_HOME="$LAB"
cleanup() { tmux kill-server >/dev/null 2>&1; chmod -R u+w "$LAB" 2>/dev/null; rm -rf "$LAB"; }
trap cleanup EXIT
git init -q -b main "$LAB/proj" && git -C "$LAB/proj" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$LAB/proj" worktree add -q -b task-t1 "$LAB/wt-t1"
mkdir -p "$LAB/data/t1" "$LAB/state"; printf '%s\n' '# Task' "## Captain's intent" '' 'Lab proof: reply DONE and do nothing else.' '' '## Firstmate spec' '' 'Do not edit any files. Reply DONE.' > "$LAB/data/t1/brief.md"
printf '%s\n' window=fmses:fm-t1 endpoint_task_id=t1 "worktree=$LAB/wt-t1" "project=$LAB/proj" harness=claude "kind=${KIND:-ship}" mode=no-mistakes yolo=off model=default effort=default > "$LAB/state/t1.meta"
PANE_CMD=${PANE_CMD:-"exec -a 'zsh (kiro-cli-term)' /bin/zsh -f -i"}
tmux new-session -d -x 200 -y 50 -s fmses -n fm-t1 -c "$LAB/wt-t1" "/bin/bash -c \"$PANE_CMD\""
sleep 1
pid=$(tmux display-message -p -t fmses:fm-t1 '#{pane_pid}')
echo "pane pid=$pid  ps comm=[$(ps -o comm= -p "$pid")]  pane_current_command=[$(tmux display-message -p -t fmses:fm-t1 '#{pane_current_command}')]"
echo "fm_backend_agent_state tmux fmses:fm-t1 -> $(bash -c ". '$ROOT/bin/fm-backend.sh'; fm_backend_agent_state tmux fmses:fm-t1")"
for verb in "$@"; do
  case "$verb" in
    settle) sleep 75; echo "(settled 75s) state: $(bash -c ". '$ROOT/bin/fm-backend.sh'; fm_backend_agent_state tmux fmses:fm-t1")"; tmux capture-pane -p -t fmses:fm-t1 | grep -v "^$" | tail -4 ;;
    probe)
      bash -c ". '$ROOT/bin/fm-backend.sh'; . '$ROOT/bin/fm-secondmate-liveness-lib.sh'; fm_secondmate_liveness_probe '$LAB/state/t1.meta' t1 full; echo \"secondmate probe -> status=\${FM_SM_LIVE_STATUS:-} state=\${FM_SM_LIVE_STATE:-} reason=\${FM_SM_LIVE_REASON:-} cause=\${FM_SM_LIVE_CAUSE:-}\"" ;;
    *)
      echo "\$ fm-control.sh t1 $verb"
      ( cd "$ROOT" && FM_CONTROL_LAUNCH_WAIT=${FM_CONTROL_LAUNCH_WAIT:-90} "$ROOT/bin/fm-control.sh" t1 $verb 2>&1 ); echo "exit=$?"
      echo "agent state after: $(bash -c ". '$ROOT/bin/fm-backend.sh'; fm_backend_agent_state tmux fmses:fm-t1")"
      tmux capture-pane -p -t fmses:fm-t1 | grep -v '^$' | tail -8 ;;
  esac
done
