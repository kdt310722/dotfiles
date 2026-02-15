export STARSHIP_CONFIG="${ZSH_CONFIG_DIR}/starship.toml"
export STARSHIP_CACHE="${ZSH_DATA_DIR}/starship"

STARSHIP_BASE_URL="https://github.com/starship/starship/releases"
STARSHIP_VERSION_FILE="${ZSH_DATA_DIR}/starship_version"
STARSHIP_BIN="${ZSH_BIN_DIR}/starship"

install_starship() {
  echo "Installing Starship..."

  local result=$(get_github_binary_download_url_and_version "latest" "$STARSHIP_BASE_URL" "unknown-linux-gnu" "apple-darwin" "x86_64" "aarch64" "starship")

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to get download URL" >&2
    return 1
  fi

  local download_url="${result%|*}.tar.gz"
  local actual_version="${result#*|}"
  local temp_dir="${ZSH_DATA_DIR}/tmp"

  create_dir "$temp_dir"

  local archive_file="${temp_dir}/starship.tar.gz"
  local sha256_file="${temp_dir}/starship.tar.gz.sha256"

  echo "Downloading Starship binary from $download_url..."

  download_file "$download_url" "$archive_file"

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download Starship binary" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  echo "Downloading SHA256 hash file..."

  download_file "${download_url}.sha256" "$sha256_file"

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download SHA256 hash file" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  local expected_hash=$(cat "$sha256_file" | awk '{print $1}')

  echo "Verifying SHA256 hash..."

  verify_sha256 "$archive_file" "$expected_hash"

  if [[ $? -ne 0 ]]; then
    echo "Error: SHA256 verification failed" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  echo "Extracting Starship binary..."

  extract_archive "$archive_file" "$temp_dir"

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to extract archive" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  mv "${temp_dir}/starship" "$STARSHIP_BIN"
  chmod +x "$STARSHIP_BIN"
  rm -rf "$temp_dir"
  echo "$(starship completions zsh)" > "${ZSH_COMPLETIONS_DIR}/_starship"

  echo "$actual_version" > "$STARSHIP_VERSION_FILE"
  echo "Starship installed successfully at $STARSHIP_BIN"
  echo "Version: $actual_version"

  return 0
}

update_starship() {
  if [[ ! -x "$STARSHIP_BIN" ]]; then
    return 1
  fi

  if [[ ! -f "$STARSHIP_VERSION_FILE" ]]; then
    return 1
  fi

  local current_version=$(cat "$STARSHIP_VERSION_FILE")
  local latest_version=$(get_latest_github_version "$STARSHIP_BASE_URL")

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to check for updates" >&2
    return 1
  fi

  if [[ "$current_version" != "$latest_version" ]]; then
    echo "New Starship version available: $latest_version (current: $current_version)"
    echo "Updating Starship..."

    install_starship

    return $?
  fi

  return 0
}

if [[ ! -x $STARSHIP_BIN ]]; then
  install_starship
fi

create_dir $STARSHIP_CACHE

if has_command starship; then
  eval "$(starship init zsh)"
fi
