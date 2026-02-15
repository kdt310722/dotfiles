if [[ ! -f "${ZSH_COMPLETIONS_DIR}/_git" ]]; then
  echo "Downloading git completions..."
  download_file "https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh" "${ZSH_COMPLETIONS_DIR}/_git"
fi
