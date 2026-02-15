export ANTIDOTE_BASE_DIR="${ZSH_DATA_DIR}/antidote"
export ANTIDOTE_SOURCE_DIR="${ANTIDOTE_BASE_DIR}/source"
export ANTIDOTE_PLUGINS_FILE="${ANTIDOTE_BASE_DIR}/plugins.txt"
export ANTIDOTE_HOME="${ANTIDOTE_BASE_DIR}"

create_dir $ANTIDOTE_BASE_DIR
create_dir $ANTIDOTE_HOME

truncate -s 0 $ANTIDOTE_PLUGINS_FILE

for plugin in "${ZSH_PLUGINS[@]}"; do
  echo $plugin >> $ANTIDOTE_PLUGINS_FILE
done

zstyle ':antidote:bundle' use-friendly-names 'yes'

if [[ ! -d $ANTIDOTE_SOURCE_DIR ]]; then
  echo "Cloning Antidote to ${ANTIDOTE_SOURCE_DIR}..."
  git clone --depth=1 https://github.com/mattmc3/antidote.git $ANTIDOTE_SOURCE_DIR
fi

if [[ ! -f "${ANTIDOTE_SOURCE_DIR}/antidote.zsh" ]]; then
  print -P "%F{red}Error: antidote.zsh not found at ${ANTIDOTE_SOURCE_DIR}/antidote.zsh%f" >&2
  return 1
fi

source "${ANTIDOTE_SOURCE_DIR}/antidote.zsh"

if ! has_command antidote; then
  print -P "%F{red}Error: antidote command not found%f" >&2
  return 1
fi

if [[ ${#ZSH_PLUGINS[@]} -gt 0 ]]; then
  antidote load $ANTIDOTE_PLUGINS_FILE
fi
