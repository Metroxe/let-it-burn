#!/usr/bin/env bash
# let-it-burn: torch your remaining Claude tokens on cigarette discourse
# Runs 10 parallel workers until rate limited or killed.

set -euo pipefail

WORKERS=10
LOGDIR="${LOGDIR:-/tmp/let-it-burn-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$LOGDIR"

PROMPTS=(
  "Write a 3000-word literary essay on the cultural significance of the cigarette in 20th century cinema. Be extremely detailed and verbose."
  "Explain the entire history of tobacco cultivation from pre-Columbian Americas to modern day Philip Morris. Leave nothing out. 4000 words minimum."
  "Write an epic poem in the style of Homer about a man's journey to find the perfect cigarette. At least 200 stanzas."
  "Describe every single brand of cigarette you know about in exhaustive detail — their flavor profiles, packaging design, target demographics, and cultural impact."
  "Write a philosophical dialogue between Sartre and Camus debating whether smoking is an act of existential freedom or nihilistic surrender. Make it extremely long and detailed."
  "Create an incredibly detailed field guide to cigarette butts found on city streets — categorize by brand, age, weather exposure, and what they reveal about the smoker. Be forensic."
  "Write the world's most comprehensive FAQ about cigarettes. Cover history, chemistry, manufacturing, culture, legislation, and trivia. Aim for encyclopedic length."
  "Compose a 5-act Shakespearean tragedy where the tragic flaw is nicotine addiction. Full iambic pentameter, extensive stage directions."
  "Write a doctoral thesis abstract, literature review, methodology, and findings section about the semiotics of cigarette advertising from 1920-2000."
  "Narrate a nature documentary script about the lifecycle of a cigarette, from tobacco seed to ashtray, in the voice of David Attenborough. Be lavishly detailed."
)

log() {
  echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOGDIR/main.log"
}

worker() {
  local id=$1
  local logfile="$LOGDIR/worker-$id.log"
  local round=0

  echo "[$(date '+%H:%M:%S')] Worker $id started" >> "$logfile"

  while true; do
    prompt="${PROMPTS[$(( (id + round) % ${#PROMPTS[@]} ))]}"
    round=$((round + 1))

    echo "[$(date '+%H:%M:%S')] Round $round — ${prompt:0:60}..." >> "$logfile"

    output=$(claude --print --model claude-opus-4-6 --max-tokens 16000 "$prompt" 2>&1) || {
      if echo "$output" | grep -qi "rate.limit\|overloaded\|529\|too many\|capacity"; then
        echo "[$(date '+%H:%M:%S')] 🚬 Rate limited after $round rounds" >> "$logfile"
        return 0
      fi
      echo "[$(date '+%H:%M:%S')] ⚠️  Error: ${output:0:200}" >> "$logfile"
      sleep 5
      continue
    }

    chars=$(echo "$output" | wc -c)
    echo "[$(date '+%H:%M:%S')] ✓ Burned ~$((chars / 4)) tokens" >> "$logfile"
  done
}

log "🔥 let-it-burn started — $WORKERS parallel workers"
log "Logs: $LOGDIR/"

pids=()
for i in $(seq 1 $WORKERS); do
  worker "$i" &
  pids+=($!)
  log "Launched worker $i (PID ${pids[-1]})"
done

# Wait for all workers, or kill them all on Ctrl+C
trap 'log "🛑 Interrupted — killing workers"; kill "${pids[@]}" 2>/dev/null; wait; exit 1' INT TERM

wait "${pids[@]}"

log "🔥 let-it-burn complete. All $WORKERS workers finished."
log "Logs: $LOGDIR/"
