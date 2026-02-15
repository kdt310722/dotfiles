export TEALDEER_DATA_DIR="${ZSH_DATA_DIR}/tealdeer"
export TEALDEER_CONFIG_PATH="${TEALDEER_DATA_DIR}/tealdeer.toml"
export TEALDEER_CACHE_PATH="${TEALDEER_DATA_DIR}/cache"
export TEALDEER_PAGES_DIR="${TEALDEER_DATA_DIR}/pages"

TEALDEER_BASE_URL="https://github.com/tealdeer-rs/tealdeer/releases"
TEALDEER_VERSION_FILE="${ZSH_DATA_DIR}/tealdeer_version"
TEALDEER_BIN="${ZSH_BIN_DIR}/tealdeer"

create_tealdeer_config() {
    cat > "$TEALDEER_CONFIG_PATH" << EOF
[updates]
auto_update = true
[directories]
cache_dir = "${TEALDEER_CACHE_PATH}"
custom_pages_dir = "${TEALDEER_PAGES_DIR}"
EOF
}

install_tealdeer() {
  echo "Installing Tealdeer..."

  local result=$(get_github_binary_download_url_and_version "latest" "$TEALDEER_BASE_URL" "linux" "macos" "x86_64" "aarch64" "tealdeer" "true")

  if [[ $? -ne 0 ]]; then
    print -P "%F{red}Error: Failed to get download URL%f" >&2
    return 1
  fi

  local download_url="${result%|*}"
  local actual_version="${result#*|}"
  local temp_dir="${ZSH_DATA_DIR}/tmp"

  create_dir "$temp_dir"

  local binary_file="${temp_dir}/tealdeer"
  local sha256_file="${temp_dir}/tealdeer.sha256"

  echo "Downloading Tealdeer binary from $download_url..."

  download_file "$download_url" "$binary_file"

  if [[ $? -ne 0 ]]; then
    print -P "%F{red}Error: Failed to download Tealdeer binary%f" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  echo "Downloading SHA256 hash file..."

  download_file "${download_url}.sha256" "$sha256_file"

  if [[ $? -ne 0 ]]; then
    print -P "%F{red}Error: Failed to download SHA256 hash file%f" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  local expected_hash=$(cat "$sha256_file" | awk '{print $1}')

  echo "Verifying SHA256 hash..."

  verify_sha256 "$binary_file" "$expected_hash"

  if [[ $? -ne 0 ]]; then
    print -P "%F{red}Error: SHA256 verification failed%f" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  echo "Downloading completions file..."

  download_file "${TEALDEER_BASE_URL}/download/v${actual_version}/completions_zsh" "${temp_dir}/_tealdeer"

  if [[ $? -ne 0 ]]; then
    print -P "%F{red}Error: Failed to download completions file%f" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  mv "${temp_dir}/tealdeer" "$TEALDEER_BIN"
  mv "${temp_dir}/_tealdeer" "${ZSH_COMPLETIONS_DIR}/_tldr"
  chmod +x "$TEALDEER_BIN"
  rm -rf "$temp_dir"
  create_dir $TEALDEER_CACHE_PATH
  create_dir $TEALDEER_PAGES_DIR
  create_tealdeer_config

  echo "$actual_version" > "$TEALDEER_VERSION_FILE"
  echo "Tealdeer installed successfully at $TEALDEER_BIN"
  echo "Version: $actual_version"

  return 0
}

update_tealdeer() {
  if [[ ! -x "$TEALDEER_BIN" ]]; then
    return 1
  fi

  if [[ ! -f "$TEALDEER_VERSION_FILE" ]]; then
    return 1
  fi

  local current_version=$(cat "$TEALDEER_VERSION_FILE")
  local latest_version=$(get_latest_github_version "$TEALDEER_BASE_URL")

  if [[ $? -ne 0 ]]; then
    print -P "%F{red}Error: Failed to check for updates%f" >&2
    return 1
  fi

  if [[ "$current_version" != "$latest_version" ]]; then
    echo "New Tealdeer version available: $latest_version (current: $current_version)"
    echo "Updating Tealdeer..."

    install_tealdeer

    return $?
  fi

  return 0
}

if [[ ! -x $TEALDEER_BIN ]]; then
  install_tealdeer
fi

alias tldr="$TEALDEER_BIN --config-path $TEALDEER_CONFIG_PATH"
