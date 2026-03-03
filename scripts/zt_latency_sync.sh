#!/usr/bin/env bash

set -euo pipefail

DB_PATH="${DB_PATH:-/Users/wzy/projects/08-Beszel/beszel_data/data.db}"
LOG_PATH="${LOG_PATH:-/Users/wzy/Library/Logs/com.wzy.beszel.zt-latency-sync.log}"
LOCK_DIR="/tmp/com.wzy.beszel.zt-latency-sync.lock"
PING_TIMEOUT_MS="${PING_TIMEOUT_MS:-1000}"
ALERT_CONFIG_FILE="${ALERT_CONFIG_FILE:-/Users/wzy/projects/08-Beszel/scripts/zt_alert.env}"

# Optional runtime overrides.
if [[ -f "$ALERT_CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ALERT_CONFIG_FILE"
fi

ALERTS_ENABLED="${ALERTS_ENABLED:-true}"
ALERT_OFFLINE_STREAK="${ALERT_OFFLINE_STREAK:-2}"
ALERT_JITTER_WARN_MS="${ALERT_JITTER_WARN_MS:-80}"
ALERT_JITTER_STREAK="${ALERT_JITTER_STREAK:-3}"
ALERT_COOLDOWN_SEC="${ALERT_COOLDOWN_SEC:-600}"
ALERT_DINGTALK_TOKEN="${ALERT_DINGTALK_TOKEN:-}"
ALERT_DINGTALK_SECRET="${ALERT_DINGTALK_SECRET:-}"
ALERT_DINGTALK_KEYWORD="${ALERT_DINGTALK_KEYWORD:-}"
ALERT_SYSTEM_FILTER_REGEX="${ALERT_SYSTEM_FILTER_REGEX:-}"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %z'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*"
}

cleanup() {
  rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
}

is_true() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

calc_jitter_ms() {
  local current="$1"
  local previous="$2"
  if (( current < 0 || previous < 0 )); then
    echo "-1"
    return 0
  fi
  if (( current >= previous )); then
    echo $((current - previous))
  else
    echo $((previous - current))
  fi
}

to_int() {
  local value="${1:-0}"
  if [[ "$value" =~ ^-?[0-9]+$ ]]; then
    echo "$value"
  else
    echo "0"
  fi
}

should_alert_with_cooldown() {
  local now_ts="$1"
  local last_alert_ts="$2"
  if (( ALERT_COOLDOWN_SEC <= 0 )); then
    return 0
  fi
  (( now_ts - last_alert_ts >= ALERT_COOLDOWN_SEC ))
}

json_escape() {
  /usr/bin/python3 - "$1" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1], ensure_ascii=False))
PY
}

send_dingtalk() {
  local title="$1"
  local text="$2"
  local url
  local payload
  local response
  local errcode
  local errmsg

  if [[ -z "$ALERT_DINGTALK_TOKEN" ]]; then
    log "alert notifier skipped: ALERT_DINGTALK_TOKEN not configured"
    return 1
  fi

  url="https://oapi.dingtalk.com/robot/send?access_token=${ALERT_DINGTALK_TOKEN}"
  if [[ -n "$ALERT_DINGTALK_SECRET" ]]; then
    local ts enc_sign
    ts="$(($(date +%s%N) / 1000000))"
    enc_sign="$(
      /usr/bin/python3 - "$ALERT_DINGTALK_SECRET" "$ts" <<'PY'
import base64
import hashlib
import hmac
import sys
import urllib.parse

secret = sys.argv[1]
ts = sys.argv[2]
data = f"{ts}\n{secret}".encode()
digest = hmac.new(secret.encode(), data, hashlib.sha256).digest()
print(urllib.parse.quote(base64.b64encode(digest).decode(), safe=""))
PY
    )"
    url="${url}&timestamp=${ts}&sign=${enc_sign}"
  fi

  payload=$(
    /usr/bin/python3 - "$title" "$text" "$ALERT_DINGTALK_KEYWORD" <<'PY'
import json
import sys
title = sys.argv[1]
text = sys.argv[2]
keyword = sys.argv[3]
if keyword:
    title = f"{keyword} {title}"
    text = f"{keyword}\n\n{text}"
payload = {"msgtype": "markdown", "markdown": {"title": title, "text": text}}
print(json.dumps(payload, ensure_ascii=False))
PY
  )

  response="$(curl -sS -X POST "$url" -H 'Content-Type: application/json' -d "$payload" || true)"
  errcode="$(
    /usr/bin/python3 - "$response" <<'PY'
import json
import sys
try:
    obj = json.loads(sys.argv[1])
    print(obj.get("errcode", ""))
except Exception:
    print("")
PY
  )"
  errmsg="$(
    /usr/bin/python3 - "$response" <<'PY'
import json
import sys
try:
    obj = json.loads(sys.argv[1])
    print(obj.get("errmsg", ""))
except Exception:
    print("invalid response")
PY
  )"

  if [[ "$errcode" != "0" ]]; then
    log "dingtalk send failed errcode=${errcode:-unknown} errmsg=${errmsg} response=${response}"
    return 1
  fi

  log "dingtalk send ok"
  return 0
}

emit_alert() {
  local alert_kind="$1"
  local system_name="$2"
  local host="$3"
  local network_label="$4"
  local latency_ms="$5"
  local jitter_ms="$6"
  local streak="$7"

  local marker
  local kind_cn
  local title
  local msg
  local latency_show
  local jitter_show

  case "$alert_kind" in
    offline)
      marker="🔴"
      kind_cn="掉线告警"
      ;;
    jitter)
      marker="🟡"
      kind_cn="波动告警"
      ;;
    recovery)
      marker="🟢"
      kind_cn="恢复通知"
      ;;
    *)
      marker="🔵"
      kind_cn="状态通知"
      ;;
  esac

  if (( latency_ms < 0 )); then
    latency_show="不可达"
  else
    latency_show="${latency_ms}ms"
  fi
  if (( jitter_ms < 0 )); then
    jitter_show="N/A"
  else
    jitter_show="${jitter_ms}ms"
  fi

  title="${marker} Beszel-ZT ${kind_cn} ${system_name}"
  msg="$(cat <<EOF
### ${marker} Beszel 网络通知
- **类型**：${kind_cn}
- **设备**：\`${system_name}\`
- **主机**：\`${host}\`
- **网络**：\`192/193-${network_label}\`
- **延迟**：\`${latency_show}\`
- **抖动**：\`${jitter_show}\`
- **连续计数**：\`${streak}\`
- **时间**：\`$(timestamp)\`
EOF
)"

  if [[ -n "$ALERT_SYSTEM_FILTER_REGEX" ]] && [[ ! "$system_name" =~ $ALERT_SYSTEM_FILTER_REGEX ]]; then
    return 0
  fi

  log "alert event kind=${alert_kind} system=${system_name} host=${host} net=${network_label} latency=${latency_ms} jitter=${jitter_ms} streak=${streak}"

  if ! is_true "$ALERTS_ENABLED"; then
    return 0
  fi

  send_dingtalk "$title" "$msg" || true
}

probe_ms() {
  local ip="$1"
  local output
  local ms

  if [[ -z "$ip" ]]; then
    echo "-1"
    return 0
  fi

  if output="$(ping -c 1 -W "$PING_TIMEOUT_MS" "$ip" 2>/dev/null)"; then
    ms="$(printf '%s\n' "$output" | awk -F'time=' '/time=/{print $2; exit}' | awk '{print $1}')"
    if [[ -n "$ms" ]]; then
      awk -v v="$ms" 'BEGIN { printf("%d\n", (v >= 0 ? v + 0.5 : v - 0.5)) }'
      return 0
    fi
  fi

  echo "-1"
}

derive_pair() {
  local host="$1"
  local octet

  if [[ "$host" =~ ^192\.168\.192\.([0-9]{1,3})$ ]]; then
    octet="${BASH_REMATCH[1]}"
    echo "$host 192.168.193.${octet}"
    return 0
  fi

  if [[ "$host" =~ ^192\.168\.193\.([0-9]{1,3})$ ]]; then
    octet="${BASH_REMATCH[1]}"
    echo "192.168.192.${octet} $host"
    return 0
  fi

  echo ""
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log "missing command: $1"
    exit 1
  }
}

main() {
  local id
  local name
  local host
  local pair
  local pair_valid
  local ip192
  local ip193
  local prev_z192
  local prev_z193
  local prev_down_streak_192
  local prev_down_streak_193
  local prev_jitter_streak_192
  local prev_jitter_streak_193
  local prev_flap_count_192
  local prev_flap_count_193
  local prev_status_192
  local prev_status_193
  local prev_last_offline_alert_192
  local prev_last_offline_alert_193
  local prev_last_jitter_alert_192
  local prev_last_jitter_alert_193
  local prev_last_recovery_alert_192
  local prev_last_recovery_alert_193
  local z192
  local z193
  local z192_jitter
  local z193_jitter
  local z192_status
  local z193_status
  local z192_down_streak
  local z193_down_streak
  local z192_jitter_streak
  local z193_jitter_streak
  local z192_flap_count
  local z193_flap_count
  local z192_last_offline_alert
  local z193_last_offline_alert
  local z192_last_jitter_alert
  local z193_last_jitter_alert
  local z192_last_recovery_alert
  local z193_last_recovery_alert
  local now_ts
  local id_escaped
  local sql
  local scanned=0

  require_cmd sqlite3
  require_cmd ping
  require_cmd awk
  require_cmd curl
  require_cmd /usr/bin/python3

  mkdir -p "$(dirname "$LOG_PATH")"
  exec >>"$LOG_PATH" 2>&1

  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "previous run still active, skip"
    exit 0
  fi
  trap cleanup EXIT

  log "start sync db=$DB_PATH"
  log "config alerts_enabled=${ALERTS_ENABLED} offline_streak=${ALERT_OFFLINE_STREAK} jitter_warn_ms=${ALERT_JITTER_WARN_MS} jitter_streak=${ALERT_JITTER_STREAK} cooldown_sec=${ALERT_COOLDOWN_SEC}"

  sql="BEGIN IMMEDIATE;"

  while IFS=$'\t' read -r \
    id name host \
    prev_z192 prev_z193 \
    prev_down_streak_192 prev_down_streak_193 \
    prev_jitter_streak_192 prev_jitter_streak_193 \
    prev_flap_count_192 prev_flap_count_193 \
    prev_status_192 prev_status_193 \
    prev_last_offline_alert_192 prev_last_offline_alert_193 \
    prev_last_jitter_alert_192 prev_last_jitter_alert_193 \
    prev_last_recovery_alert_192 prev_last_recovery_alert_193; do
    if [[ -z "${id:-}" ]]; then
      continue
    fi

    scanned=$((scanned + 1))
    now_ts="$(date +%s)"
    prev_z192="$(to_int "$prev_z192")"
    prev_z193="$(to_int "$prev_z193")"
    prev_down_streak_192="$(to_int "$prev_down_streak_192")"
    prev_down_streak_193="$(to_int "$prev_down_streak_193")"
    prev_jitter_streak_192="$(to_int "$prev_jitter_streak_192")"
    prev_jitter_streak_193="$(to_int "$prev_jitter_streak_193")"
    prev_flap_count_192="$(to_int "$prev_flap_count_192")"
    prev_flap_count_193="$(to_int "$prev_flap_count_193")"
    prev_last_offline_alert_192="$(to_int "$prev_last_offline_alert_192")"
    prev_last_offline_alert_193="$(to_int "$prev_last_offline_alert_193")"
    prev_last_jitter_alert_192="$(to_int "$prev_last_jitter_alert_192")"
    prev_last_jitter_alert_193="$(to_int "$prev_last_jitter_alert_193")"
    prev_last_recovery_alert_192="$(to_int "$prev_last_recovery_alert_192")"
    prev_last_recovery_alert_193="$(to_int "$prev_last_recovery_alert_193")"
    prev_status_192="${prev_status_192:-}"
    prev_status_193="${prev_status_193:-}"
    pair="$(derive_pair "$host")"
    pair_valid=0
    ip192=""
    ip193=""

    if [[ -n "$pair" ]]; then
      pair_valid=1
      ip192="${pair%% *}"
      ip193="${pair##* }"
    fi

    # For non-192/193 hosts (e.g. domain), keep deterministic placeholder -1.
    z192="$(probe_ms "$ip192")"
    z193="$(probe_ms "$ip193")"

    if (( pair_valid == 1 )); then
      z192_jitter="$(calc_jitter_ms "$z192" "$prev_z192")"
      z193_jitter="$(calc_jitter_ms "$z193" "$prev_z193")"

      if (( z192 >= 0 )); then z192_status="up"; else z192_status="down"; fi
      if (( z193 >= 0 )); then z193_status="up"; else z193_status="down"; fi

      if [[ "$z192_status" == "down" ]]; then z192_down_streak=$((prev_down_streak_192 + 1)); else z192_down_streak=0; fi
      if [[ "$z193_status" == "down" ]]; then z193_down_streak=$((prev_down_streak_193 + 1)); else z193_down_streak=0; fi

      if (( z192_jitter >= ALERT_JITTER_WARN_MS )); then z192_jitter_streak=$((prev_jitter_streak_192 + 1)); else z192_jitter_streak=0; fi
      if (( z193_jitter >= ALERT_JITTER_WARN_MS )); then z193_jitter_streak=$((prev_jitter_streak_193 + 1)); else z193_jitter_streak=0; fi

      z192_flap_count="$prev_flap_count_192"
      z193_flap_count="$prev_flap_count_193"
      if [[ "$prev_status_192" =~ ^(up|down)$ ]] && [[ "$prev_status_192" != "$z192_status" ]]; then
        z192_flap_count=$((prev_flap_count_192 + 1))
      fi
      if [[ "$prev_status_193" =~ ^(up|down)$ ]] && [[ "$prev_status_193" != "$z193_status" ]]; then
        z193_flap_count=$((prev_flap_count_193 + 1))
      fi
    else
      z192_jitter="-1"
      z193_jitter="-1"
      z192_status="na"
      z193_status="na"
      z192_down_streak=0
      z193_down_streak=0
      z192_jitter_streak=0
      z193_jitter_streak=0
      z192_flap_count="$prev_flap_count_192"
      z193_flap_count="$prev_flap_count_193"
    fi

    z192_last_offline_alert="$prev_last_offline_alert_192"
    z193_last_offline_alert="$prev_last_offline_alert_193"
    z192_last_jitter_alert="$prev_last_jitter_alert_192"
    z193_last_jitter_alert="$prev_last_jitter_alert_193"
    z192_last_recovery_alert="$prev_last_recovery_alert_192"
    z193_last_recovery_alert="$prev_last_recovery_alert_193"

    if (( pair_valid == 1 )); then
      if [[ "$z192_status" == "down" ]] && (( z192_down_streak >= ALERT_OFFLINE_STREAK )); then
        if (( prev_down_streak_192 < ALERT_OFFLINE_STREAK )) || (( prev_last_offline_alert_192 <= 0 )) || should_alert_with_cooldown "$now_ts" "$prev_last_offline_alert_192"; then
          emit_alert "offline" "$name" "$host" "192" "$z192" "$z192_jitter" "$z192_down_streak"
          z192_last_offline_alert="$now_ts"
        fi
      fi
      if [[ "$z193_status" == "down" ]] && (( z193_down_streak >= ALERT_OFFLINE_STREAK )); then
        if (( prev_down_streak_193 < ALERT_OFFLINE_STREAK )) || (( prev_last_offline_alert_193 <= 0 )) || should_alert_with_cooldown "$now_ts" "$prev_last_offline_alert_193"; then
          emit_alert "offline" "$name" "$host" "193" "$z193" "$z193_jitter" "$z193_down_streak"
          z193_last_offline_alert="$now_ts"
        fi
      fi

      if [[ "$z192_status" == "up" ]] && [[ "$prev_status_192" == "down" ]] && (( prev_down_streak_192 >= ALERT_OFFLINE_STREAK )); then
        if should_alert_with_cooldown "$now_ts" "$prev_last_recovery_alert_192"; then
          emit_alert "recovery" "$name" "$host" "192" "$z192" "$z192_jitter" "$prev_down_streak_192"
          z192_last_recovery_alert="$now_ts"
        fi
      fi
      if [[ "$z193_status" == "up" ]] && [[ "$prev_status_193" == "down" ]] && (( prev_down_streak_193 >= ALERT_OFFLINE_STREAK )); then
        if should_alert_with_cooldown "$now_ts" "$prev_last_recovery_alert_193"; then
          emit_alert "recovery" "$name" "$host" "193" "$z193" "$z193_jitter" "$prev_down_streak_193"
          z193_last_recovery_alert="$now_ts"
        fi
      fi

      if [[ "$z192_status" == "up" ]] && (( z192_jitter >= ALERT_JITTER_WARN_MS )) && (( z192_jitter_streak >= ALERT_JITTER_STREAK )); then
        if (( prev_jitter_streak_192 < ALERT_JITTER_STREAK )) || (( prev_last_jitter_alert_192 <= 0 )) || should_alert_with_cooldown "$now_ts" "$prev_last_jitter_alert_192"; then
          emit_alert "jitter" "$name" "$host" "192" "$z192" "$z192_jitter" "$z192_jitter_streak"
          z192_last_jitter_alert="$now_ts"
        fi
      fi
      if [[ "$z193_status" == "up" ]] && (( z193_jitter >= ALERT_JITTER_WARN_MS )) && (( z193_jitter_streak >= ALERT_JITTER_STREAK )); then
        if (( prev_jitter_streak_193 < ALERT_JITTER_STREAK )) || (( prev_last_jitter_alert_193 <= 0 )) || should_alert_with_cooldown "$now_ts" "$prev_last_jitter_alert_193"; then
          emit_alert "jitter" "$name" "$host" "193" "$z193" "$z193_jitter" "$z193_jitter_streak"
          z193_last_jitter_alert="$now_ts"
        fi
      fi
    fi

    id_escaped="${id//\'/\'\'}"
    sql="${sql}UPDATE systems SET info=json_set(COALESCE(info,'{}'),"
    sql="${sql}'$.z192',${z192},'$.z193',${z193},"
    sql="${sql}'$.z192_jitter',${z192_jitter},'$.z193_jitter',${z193_jitter},"
    sql="${sql}'$.z192_status','${z192_status}','$.z193_status','${z193_status}',"
    sql="${sql}'$.z192_down_streak',${z192_down_streak},'$.z193_down_streak',${z193_down_streak},"
    sql="${sql}'$.z192_jitter_streak',${z192_jitter_streak},'$.z193_jitter_streak',${z193_jitter_streak},"
    sql="${sql}'$.z192_flap_count',${z192_flap_count},'$.z193_flap_count',${z193_flap_count},"
    sql="${sql}'$.z192_last_offline_alert_ts',${z192_last_offline_alert},'$.z193_last_offline_alert_ts',${z193_last_offline_alert},"
    sql="${sql}'$.z192_last_jitter_alert_ts',${z192_last_jitter_alert},'$.z193_last_jitter_alert_ts',${z193_last_jitter_alert},"
    sql="${sql}'$.z192_last_recovery_alert_ts',${z192_last_recovery_alert},'$.z193_last_recovery_alert_ts',${z193_last_recovery_alert},"
    sql="${sql}'$.zt_probe_ts',${now_ts}) WHERE id='${id_escaped}';"

    log "system=${name} host=${host} z192=${z192} z193=${z193} z192_jitter=${z192_jitter} z193_jitter=${z193_jitter} z192_status=${z192_status} z193_status=${z193_status} z192_down=${z192_down_streak} z193_down=${z193_down_streak} z192_js=${z192_jitter_streak} z193_js=${z193_jitter_streak}"
  done < <(sqlite3 -readonly -separator $'\t' "$DB_PATH" -cmd ".timeout 5000" "SELECT id,name,host,COALESCE(CAST(json_extract(info,'$.z192') AS INTEGER),-1),COALESCE(CAST(json_extract(info,'$.z193') AS INTEGER),-1),COALESCE(CAST(json_extract(info,'$.z192_down_streak') AS INTEGER),0),COALESCE(CAST(json_extract(info,'$.z193_down_streak') AS INTEGER),0),COALESCE(CAST(json_extract(info,'$.z192_jitter_streak') AS INTEGER),0),COALESCE(CAST(json_extract(info,'$.z193_jitter_streak') AS INTEGER),0),COALESCE(CAST(json_extract(info,'$.z192_flap_count') AS INTEGER),0),COALESCE(CAST(json_extract(info,'$.z193_flap_count') AS INTEGER),0),COALESCE(json_extract(info,'$.z192_status'),''),COALESCE(json_extract(info,'$.z193_status'),''),COALESCE(CAST(json_extract(info,'$.z192_last_offline_alert_ts') AS INTEGER),0),COALESCE(CAST(json_extract(info,'$.z193_last_offline_alert_ts') AS INTEGER),0),COALESCE(CAST(json_extract(info,'$.z192_last_jitter_alert_ts') AS INTEGER),0),COALESCE(CAST(json_extract(info,'$.z193_last_jitter_alert_ts') AS INTEGER),0),COALESCE(CAST(json_extract(info,'$.z192_last_recovery_alert_ts') AS INTEGER),0),COALESCE(CAST(json_extract(info,'$.z193_last_recovery_alert_ts') AS INTEGER),0) FROM systems ORDER BY name;")

  sql="${sql}COMMIT;"
  sqlite3 "$DB_PATH" -cmd ".timeout 15000" "$sql" >/dev/null

  log "sync done scanned=${scanned}"
}

main "$@"
