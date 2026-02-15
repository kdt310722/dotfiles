export PROJECT_PATHS=(
  "$HOME/Projects"
)

export ZSH_UPDATE_INTERVAL=1 # days

export ZSH_PLUGINS=(
  'mattmc3/zephyr path:plugins/environment'
  'mattmc3/zephyr path:plugins/homebrew conditional:is-macos'
  'mattmc3/zephyr path:plugins/history'
  'mattmc3/ez-compinit'
  'zsh-users/zsh-completions kind:fpath path:src'
  'mattmc3/zephyr path:plugins/color'
  'mattmc3/zephyr path:plugins/directory'
  'Tarrasch/zsh-bd'
  'ohmyzsh/ohmyzsh path:plugins/command-not-found'
  'ohmyzsh/ohmyzsh path:plugins/pj'
  'zdharma-continuum/fast-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
)

export UPDATE_COMMANDS=(
  "antidote update"
  "update_starship"
  "update_tealdeer"
)

export ZSH_DIR="${ZDOTDIR:-$HOME}/.zsh"
export ZSH_CONFIG_DIR="${ZSH_DIR}/config"
export ZSH_DATA_DIR="${ZSH_DIR}/data"
export ZSH_BIN_DIR="${ZSH_DATA_DIR}/bin"
export ZSH_INITIALIZED_FILE="${ZSH_DATA_DIR}/INITIALIZED"
export ZSH_COMPDUMP="${ZSH_DATA_DIR}/zcompdump-${ZSH_VERSION}"
export ZSH_COMPLETIONS_DIR="${ZSH_DATA_DIR}/completions"

export PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
export ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"
export PATH="${ZSH_BIN_DIR}:$PATH"

fpath=($ZSH_COMPLETIONS_DIR $fpath)

if [[ ! -f "${ZSH_DIR}/helpers.zsh" ]]; then
  print -P "%F{red}Error: helpers.zsh not found at ${ZSH_DIR}/helpers.zsh%f" >&2
  print -P "%F{red}Error: This file is required for ZSH configuration to work properly.%f" >&2
  return 1
fi

source "${ZSH_DIR}/helpers.zsh"

create_dir $ZSH_CONFIG_DIR
create_dir $ZSH_DATA_DIR
create_dir $ZSH_BIN_DIR
create_dir $ZSH_COMPLETIONS_DIR

source_if_exists "${ZSH_DIR}/misc.zsh"
source_if_exists "${ZSH_DIR}/completions.zsh"
source_if_exists "${ZSH_DIR}/aliases.zsh"
source_if_exists "${ZSH_DIR}/eza.zsh"
source_if_exists "${ZSH_DIR}/tealdeer.zsh"
source_if_exists "${ZSH_DIR}/starship.zsh"
source_if_exists "${ZSH_DIR}/antidote.zsh"
source_if_exists "${ZSH_DIR}/updater.zsh"

touch $ZSH_INITIALIZED_FILE

if has_command bun; then
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

if has_command npm; then
  export NODE_PATH="${NODE_PATH:-$(npm root -g)}"
fi

if has_command yarn; then
  export YARN_GLOBAL_BIN="${YARN_GLOBAL_BIN:-$(yarn global bin)}"
  export PATH="$YARN_GLOBAL_BIN:$PATH"
fi

if has_command pnpm; then
  export PNPM_HOME="$HOME/.pnpm"
  export PATH="$PNPM_HOME:$PATH"
fi
