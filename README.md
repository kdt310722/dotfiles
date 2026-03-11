# dotfiles

Personal dotfiles for macOS and Linux — managed with [antidote](https://getantidote.github.io/) and [Starship](https://starship.rs/).

## Structure

```
dotfiles/
├── .zshrc              # Entry point — sets env vars, sources all zsh configs
├── .env                # Local secrets/overrides (git-ignored)
├── .zsh/
│   ├── helpers.zsh     # Utility functions (create_dir, source_if_exists, ...)
│   ├── updater.zsh     # Auto-update scheduler (dotfiles-first strategy)
│   ├── antidote.zsh    # Plugin manager setup
│   ├── aliases.zsh     # Shell aliases
│   ├── nvm.zsh         # Node version manager config
│   ├── eza.zsh         # eza (modern ls) config
│   ├── starship.zsh    # Starship prompt init
│   ├── tealdeer.zsh    # tldr client config
│   ├── direnv.zsh      # direnv hook
│   ├── completions.zsh # Completion setup
│   └── misc.zsh        # Miscellaneous settings
└── install-tools.sh    # Cross-platform tool installer (macOS/Ubuntu/Debian/Fedora/Arch)
```

## Installation

```sh
git clone git@github.com:kdt310722/dotfiles.git ~/dotfiles
echo 'ZDOTDIR=$HOME/dotfiles' >> ~/.zshenv
exec zsh
```

On first shell, missing tools are not installed automatically — run the installer manually:

```sh
~/dotfiles/install-tools.sh
```

## Auto-update

Updates run in the background once per day (configurable via `ZSH_UPDATE_INTERVAL`).

**Strategy:** dotfiles itself is checked first. If there are new remote commits, they are pulled and all other updates (plugins, tools) are deferred to the next session — ensuring config changes take effect before anything else runs.

Commands that run on update are defined in `.zshrc`:

```zsh
export UPDATE_COMMANDS=(
  "antidote update"
  "update_starship"
  "update_tealdeer"
  "update_nvm_and_node"
)
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `ZSH_UPDATE_INTERVAL` | `1` | Days between auto-updates |
| `ZSH_PLUGINS` | see `.zshrc` | antidote plugin list |
| `UPDATE_COMMANDS` | see `.zshrc` | Commands run on auto-update |
| `PROJECT_PATHS` | `~/Projects` | Paths used by the `pj` plugin |
