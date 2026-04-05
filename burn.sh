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

COLORS=(31 32 33 34 35 36 91 92 93 94)

worker() {
  local id=$1
  local logfile="$LOGDIR/worker-$id.log"
  local round=0
  local color="${COLORS[$(( (id - 1) % ${#COLORS[@]} ))]}"
  local tag="\033[${color}m[worker $id]\033[0m"

  while true; do
    prompt="${PROMPTS[$(( (id + round) % ${#PROMPTS[@]} ))]}"
    round=$((round + 1))

    echo -e "\n$tag 🔥 Round $round — ${prompt:0:60}..."

    output=$(claude --print --model claude-opus-4-6 --tools "" --bare "$prompt" 2>&1) || {
      if echo "$output" | grep -qi "rate.limit\|overloaded\|529\|too many\|capacity"; then
        echo -e "$tag 🚬 Rate limited after $round rounds"
        return 0
      fi
      echo -e "$tag ⚠️  Error: ${output:0:200}"
      sleep 5
      continue
    }

    # Print response with colored prefix on each line
    echo "$output" | while IFS= read -r line; do
      echo -e "$tag $line"
    done

    chars=$(echo "$output" | wc -c)
    echo -e "$tag ✓ Burned ~$((chars / 4)) tokens"

    # Full output to log
    echo "[$(date '+%H:%M:%S')] Round $round — ~$((chars / 4)) tokens" >> "$logfile"
    echo "$output" >> "$logfile"
  done
}

echo "🔥 let-it-burn — $WORKERS parallel workers"
echo ""

pids=()
for i in $(seq 1 $WORKERS); do
  worker "$i" &
  pids+=($!)
done

# Wait for all workers, or kill them all on Ctrl+C
trap 'trap - INT TERM; echo ""; echo "🛑 Killed all workers"; kill -- -$$; wait; exit 1' INT TERM

wait "${pids[@]}"

echo ""
echo "🔥 let-it-burn complete. All $WORKERS workers finished."
echo "Logs: $LOGDIR/"
