if has_command eza; then
    alias ls='eza --icons --classify --group-directories-first --time-style=long-iso --group --color-scale'
    alias l.='ls -d .*'
    alias lD='ls -D'
    alias lS='ls -1'

    alias ll='ls -l'
    alias la='ll -a'

    alias lA='ll --sort=acc'
    alias lC='ll --sort=cr'
    alias lM='ll --sort=mod'
    alias lS='ll --sort=size'
    alias lX="ll --sort=ext"
    alias llm='lM'

    alias l='la -a'
    alias lsa='l'
    alias lx='l -HSUimu'
    alias lxa='lx -@'

    alias lt='ls -T'
    alias tree='lt'
fi
