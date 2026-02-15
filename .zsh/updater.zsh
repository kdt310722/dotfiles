UPDATER_LOCK_FILE="${ZSH_DATA_DIR}/updater.lock"
UPDATER_TIMESTAMP_FILE="${ZSH_DATA_DIR}/last_update"
UPDATER_LOCK_FILE_AGE_LIMIT=600 # seconds

should_run_update() {
  if [[ ! -f "$UPDATER_TIMESTAMP_FILE" ]]; then
    return 0
  fi

  local last_update=$(cat "$UPDATER_TIMESTAMP_FILE")
  local current_time=$(date +%s)
  local interval_seconds=$((ZSH_UPDATE_INTERVAL * 86400))
  local time_diff=$((current_time - last_update))

  if [[ $time_diff -gt $interval_seconds ]]; then
    return 0
  fi

  return 1
}

acquire_lock() {
  local max_attempts=3
  local attempt=0

  while [[ $attempt -lt $max_attempts ]]; do
    if mkdir "$UPDATER_LOCK_FILE" 2>/dev/null; then
      return 0
    fi

    if [[ -d "$UPDATER_LOCK_FILE" ]]; then
      local lock_mtime=""

      if [[ "$PLATFORM" == "darwin" ]]; then
        lock_mtime=$(stat -f %m "$UPDATER_LOCK_FILE" 2>/dev/null)
      else
        lock_mtime=$(stat -c %Y "$UPDATER_LOCK_FILE" 2>/dev/null)
      fi

      if [[ -z "$lock_mtime" ]]; then
        print -P "%F{red}Warning: Cannot read lock file timestamp, assuming lock is active.%f" >&2
        attempt=$((attempt + 1))
        sleep 1
        continue
      fi

      local lock_age=$(($(date +%s) - lock_mtime))

      if [[ $lock_age -gt $UPDATER_LOCK_FILE_AGE_LIMIT ]]; then
        echo "Removing stale lock (age: ${lock_age}s)" >&2
        rm -rf "$UPDATER_LOCK_FILE"
        continue
      fi
    fi

    attempt=$((attempt + 1))
    sleep 1
  done

  return 1
}

release_lock() {
  rm -rf "$UPDATER_LOCK_FILE"
}

run_updates() {
  if ! should_run_update; then
    return 0
  fi

  if ! acquire_lock; then
    return 1
  fi

  trap "release_lock" EXIT INT TERM
  echo "Running updates..."

  local failed=0

  for cmd in "${UPDATE_COMMANDS[@]}"; do
    echo "Executing: $cmd"
    eval "$cmd"

    if [[ $? -ne 0 ]]; then
      print -P "%F{red}Error: Warning: Update command failed: $cmd%f" >&2
      failed=1
    fi
  done

  if [[ $failed -eq 0 ]]; then
    date +%s > "$UPDATER_TIMESTAMP_FILE"
    echo "Updates completed successfully."
  else
    print -P "%F{red}Error: Some updates failed. Will retry on next session.%f" >&2
  fi

  release_lock
  trap - EXIT INT TERM

  return $failed
}

if [[ ${#UPDATE_COMMANDS[@]} -gt 0 ]]; then
  if [[ -f "$ZSH_INITIALIZED_FILE" ]]; then
    run_updates
  else
    date +%s > "$UPDATER_TIMESTAMP_FILE"
  fi
fi
