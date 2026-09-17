# welcome dashboard — once per terminal; not in tmux panes, nvim, VS Code or over SSH
if [[ -z $WELCOME_SHOWN && -z $TMUX && -z $NVIM && -z $SSH_CONNECTION && $TERM_PROGRAM != vscode ]]; then
  export WELCOME_SHOWN=1
  welcome
fi
