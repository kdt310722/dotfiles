UPDATER_LOCK_FILE="${ZSH_DATA_DIR}/updater.lock"
UPDATER_TIMESTAMP_FILE="${ZSH_DATA_DIR}/last_update"
UPDATER_LOCK_FILE_AGE_LIMIT=600 # seconds
DOTFILES_DIR="${ZDOTDIR:-$HOME}"

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

# Returns 0 if dotfiles is up-to-date (proceed with other updates)
# Returns 1 if dotfiles was just pulled (skip other updates this session)
check_and_update_dotfiles() {
  if [[ ! -d "${DOTFILES_DIR}/.git" ]]; then
    return 0
  fi

  echo "Checking dotfiles for updates..."

  if ! git -C "$DOTFILES_DIR" fetch --quiet 2>/dev/null; then
    print -P "%F{yellow}Warning: Could not fetch dotfiles remote, skipping check.%f" >&2
    return 0
  fi

  local behind
  behind=$(git -C "$DOTFILES_DIR" rev-list HEAD..FETCH_HEAD --count 2>/dev/null)

  if [[ -z "$behind" || "$behind" -eq 0 ]]; then
    return 0
  fi

  echo "Dotfiles has ${behind} new commit(s). Pulling..."

  if git -C "$DOTFILES_DIR" pull --ff-only 2>&1; then
    print -P "%F{green}Dotfiles updated. Other updates will run next session.%f"
    return 1
  else
    print -P "%F{red}Warning: Dotfiles pull failed. Proceeding with other updates.%f" >&2
    return 0
  fi
}

run_updates() {
  if ! acquire_lock; then
    return 1
  fi

  trap "release_lock" EXIT INT TERM

  if ! check_and_update_dotfiles; then
    release_lock
    trap - EXIT INT TERM
    return 0
  fi

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
    date +%s >! "$UPDATER_TIMESTAMP_FILE"
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
    if should_run_update; then
      bgr "run_updates" "zsh-updater" "ZSH Update" "ZSH Update Completed" "ZSH Update Failed"
    fi
  else
    date +%s >! "$UPDATER_TIMESTAMP_FILE"
  fi
fi
