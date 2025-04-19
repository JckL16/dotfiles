export ZSH="$HOME/.oh-my-zsh"

[ -f ~/.aliases ] && source ~/.aliases

ZSH_THEME=""

plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)

source $ZSH/oh-my-zsh.sh

eval "$(starship init zsh)"