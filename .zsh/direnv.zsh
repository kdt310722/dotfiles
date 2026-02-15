DIRENV_VERSION="latest"
DIRENV_BASE_URL="https://github.com/direnv/direnv/releases"
DIRENV_VERSION_FILE="${ZSH_DATA_DIR}/direnv_version"
DIRENV_BIN="${ZSH_BIN_DIR}/direnv"

install_direnv() {
  echo "Installing DirENV..."

  local result=$(get_github_binary_download_url_and_version "$DIRENV_VERSION" "$DIRENV_BASE_URL" "linux" "darwin" "amd64" "arm64" "direnv" "true" ".")

  if [[ $? -ne 0 ]]; then
    print -P "%F{red}Error: Failed to get download URL%f" >&2
    return 1
  fi

  local download_url="${result%|*}"
  local actual_version="${result#*|}"
  local temp_dir="${ZSH_DATA_DIR}/tmp"

  create_dir "$temp_dir"

  local binary_file="${temp_dir}/direnv"

  echo "Downloading DirENV binary from $download_url..."

  download_file "$download_url" "$binary_file"

  if [[ $? -ne 0 ]]; then
    print -P "%F{red}Error: Failed to download DirENV binary%f" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  mv "${temp_dir}/direnv" "$DIRENV_BIN"
  chmod +x "$DIRENV_BIN"
  rm -rf "$temp_dir"

  echo "$actual_version" > "$DIRENV_VERSION_FILE"
  echo "DirENV installed successfully at $DIRENV_BIN"
  echo "Version: $actual_version"

  return 0
}

update_direnv() {
  if [[ ! -x "$DIRENV_BIN" ]]; then
    return 1
  fi

  if [[ ! -f "$DIRENV_VERSION_FILE" ]]; then
    return 1
  fi

  local current_version=$(cat "$DIRENV_VERSION_FILE")
  local latest_version=$DIRENV_VERSION

  if [[ "$latest_version" == "latest" ]]; then
    latest_version=$(get_latest_github_version "$DIRENV_BASE_URL")
  fi

  if [[ $? -ne 0 ]]; then
    print -P "%F{red}Error: Failed to check for updates%f" >&2
    return 1
  fi

  if [[ "$current_version" != "$latest_version" ]]; then
    echo "New DirENV version available: $latest_version (current: $current_version)"
    echo "Updating DirENV..."

    install_direnv

    return $?
  fi

  return 0
}

if [[ ! -x $DIRENV_BIN ]]; then
  install_direnv
fi

ZSH_PLUGINS+=('ohmyzsh/ohmyzsh path:plugins/direnv')
