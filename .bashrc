#!/usr/bin/env bash

# ==============================================================================
#  USER BASH CONFIGURATION (~/.bashrc)
# ==============================================================================

# --- 1. Shell Behavior & History ---
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

shopt -s histappend      # Append to history, don't overwrite
shopt -s checkwinsize    # Update LINES/COLUMNS after each command
shopt -s globstar        # Allow recursive globbing (e.g., ls **/file.txt)

HISTCONTROL=ignoreboth   # No duplicates or lines starting with space
HISTSIZE=5000            # Increased for convenience
HISTFILESIZE=10000

# --- 2. Environment Variables ---
export GIT_SSH=ssh
export RSHELL_PORT=/dev/ttyUSB0
export JAVA_HOME=/usr/lib/jvm/default-java
export NDK="$HOME/Android/Sdk/ndk/25.2.9519653"
export NDK_PATH="$HOME/.local/share/android-ndk"
export PICO_SDK_PATH="$HOME/Development/pico-sdk"
export STM32_PRG_PATH="$HOME/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin"

umask 022

# --- 3. Secure Secrets Handling ---
if [[ -f "$HOME/.bash_secrets" ]]; then
    source "$HOME/.bash_secrets"
else
    # Create the file with strict permissions if it doesn't exist
    touch "$HOME/.bash_secrets"
    chmod 600 "$HOME/.bash_secrets"
    echo "# Export your private keys here" >> "$HOME/.bash_secrets"
fi

# --- 4. Dynamic Path Construction ---
# Cleanly add paths only if they exist on the current system
PATH_ADDITIONS=(
    "$HOME/bin"
    "$HOME/.local/bin"
    "$JAVA_HOME/bin"
    "$HOME/Android/Sdk/platform-tools"
    "$STM32_PRG_PATH"
    "/snap/bin"
)

for p in "${PATH_ADDITIONS[@]}"; do
    if [[ -d "$p" && :$PATH: != *:"$p":* ]]; then
        export PATH="$p:$PATH"
    fi
done

# --- 5. Pyenv Auto-Installation & Initialization ---
export PYENV_ROOT="$HOME/.pyenv"
if [[ ! -d "$PYENV_ROOT" ]]; then
    echo "[INFO] Pyenv not found. Initiating auto-install..."
    curl -fsSL https://pyenv.run | bash
fi

if [[ -d "$PYENV_ROOT/bin" ]]; then
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi

# --- 6. Prompt & Colors ---
force_color_prompt=yes
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    fi
fi

if [ "$color_prompt" = yes ]; then
    # Green user@host : Blue current directory
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# --- 7. Aliases ---
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Load custom aliases if they exist
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# --- 8. Completion ---
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
