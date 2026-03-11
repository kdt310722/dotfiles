export NVM_DIR="$ZSH_DATA_DIR/nvm"
export NVM_SYMLINK_CURRENT=true

export NVM_DEFAULT_PACKAGES=(
    '@antfu/ni'
    'bun'
    'deno'
    'npm-check'
    'tsx'
    'zx'
)

alias latest_nvm_version="cd $NVM_DIR && git describe --abbrev=0 --tags --match \"v[0-9]*\" \$(git rev-list --tags --max-count=1)"

create_nvm_default_packages_file() {
    truncate -s 0 "$NVM_DIR/default-packages"

    for package in "${NVM_DEFAULT_PACKAGES[@]}"; do
      echo $package >> "$NVM_DIR/default-packages"
    done
}

install_nvm() {
  echo "Installing NVM..."

  rm -rf "$NVM_DIR"
  git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"

  cd "$NVM_DIR"
  git checkout $latest_nvm_version
  create_nvm_default_packages_file
  \. "$NVM_DIR/nvm.sh" --no-use
}

update_nvm() {
  if [[ ! -d $NVM_DIR ]]; then
    return 1
  fi

  echo "Updating NVM..."

  cd "$NVM_DIR"
  git fetch --tags origin
  git checkout $(latest_nvm_version)
  \. "$NVM_DIR/nvm.sh"
}

install_node() {
  nvm install --lts --latest-npm
  nvm use --lts
  nvm alias default node

  if ! has_command node; then
    rm -rf "$NVM_DIR"
    print -P "%F{red}Error: npm command not found after node installation%f" >&2
    return 1
  fi
}

update_nvm_and_node() {
  update_nvm
  install_node

  if has_command corepack; then
    corepack prepare yarn@latest --activate
    corepack prepare pnpm@latest --activate
  fi

  if has_command npm-check; then
    npm-check -gy
  fi

  if has_command pnpm; then
    pnpm -g up --latest
  fi

  if has_command bun; then
    bun update -g --latest
  fi

  return 0
}

sync_global_npm_packages() {
    if [[ -z "$NVM_BIN" ]]; then
        return
    fi

    local GLOBAL_NODE_MODULES="$NVM_BIN/../lib/node_modules"
    local MISSING_PKGS=()

    for pkg in "${NVM_DEFAULT_PACKAGES[@]}"; do
        if [[ ! -d "$GLOBAL_NODE_MODULES/$pkg" ]]; then
            MISSING_PKGS+=("$pkg")
        fi
    done

    if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
        bgr `npm install -g "${MISSING_PKGS[@]}"` "global-npm-packages-sync" "Global NPM Packages Sync" "Global NPM Packages Sync Completed" "Global NPM Packages Sync Failed"
    fi
}

if [[ ! -d $NVM_DIR ]]; then
  install_nvm

  if ! has_command nvm; then
    rm -rf "$NVM_DIR"
    print -P "%F{red}Error: nvm command not found after installation%f" >&2
    return 1
  fi

  install_node

  if has_command corepack; then
    corepack enable yarn
    corepack enable pnpm
  fi
else
  create_nvm_default_packages_file
  \. "$NVM_DIR/nvm.sh"
  sync_global_npm_packages
fi

NVM_PATHS=()

if has_command bun; then
  export BUN_INSTALL="$HOME/.bun"
  export BUN_BIN_DIR="$BUN_INSTALL/bin"
  export PATH="$BUN_BIN_DIR:$PATH"
  
  NVM_PATHS+=("$BUN_BIN_DIR")
fi

if has_command npm; then
  export NODE_PATH="${NODE_PATH:-$(npm root -g)}"
fi

if has_command pnpm; then
  export PNPM_HOME="$HOME/.pnpm"
  export PATH="$PNPM_HOME:$PATH"

  NVM_PATHS+=("$PNPM_HOME")
fi

for dir in "$NVM_DIR/versions/node"/*/; do
  [[ -d "$dir/bin" ]] && NVM_PATHS+=("${dir%/}/bin")
done

case "$PLATFORM" in
  darwin)
    local nvm_paths_file="$ZSH_DATA_DIR/nvm-paths"
    printf '%s\n' "${NVM_PATHS[@]}" > "$nvm_paths_file"

    if [[ ! -L /etc/paths.d/nvm ]]; then
      sudo ln -sf "$nvm_paths_file" /etc/paths.d/nvm
    fi
    ;;
  linux)
    local nvm_paths_file="$ZSH_DATA_DIR/nvm-paths.sh"
    printf 'export PATH="%s:$PATH"\n' "${NVM_PATHS[@]}" > "$nvm_paths_file"

    if [[ ! -L /etc/profile.d/nvm.sh ]]; then
      sudo ln -sf "$nvm_paths_file" /etc/profile.d/nvm.sh
    fi
    ;;
esac
