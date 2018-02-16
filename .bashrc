#!/usr/bin/env bash
#

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if [ -f ~/.bash_customs ]; then
    . ~/.bash_customs
fi

if [ -f ~/.bash_powergit ]; then
    . ~/.bash_powergit
fi
