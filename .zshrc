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
  echo "Error: helpers.zsh not found at ${ZSH_DIR}/helpers.zsh" >&2
  echo "This file is required for ZSH configuration to work properly." >&2
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
