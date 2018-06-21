#!/usr/bin/env bash
#

#
# If not running interactively, don't do anything
#
case $- in
    *i*) ;;
      *) return;;
esac

#
# History Management:
#  - don't put duplicate lines
#  - erase duplicate lines
#
HISTCONTROL=ignoredups:erasedups

#  - append to the history file, don't overwrite it
#  - check the window size after each command and, if necessary,
#     update the values of lines and columns
#
shopt -s histappend
shopt -s checkwinsize

#  - setting history length
#
HISTSIZE=100000
HISTFILESIZE=100000

#  - saving and reloading the history after each command finishes
#
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

#
# Defining the default editor to use
#
VISUAL="nano"
EDITOR="${VISUAL}"

if [ -f ~/.bash_aliases ]
then
    source ~/.bash_aliases
fi
if [ -f ~/.bash_customs ]
then
    source ~/.bash_customs
fi
if [ -f ~/.bash_exports ]
then
    source ~/.bash_exports
fi
if [ -f ~/.bash_functions ]
then
    source ~/.bash_functions
fi
