#!/bin/bash

if playerctl status > /dev/null 2>&1; then
    TITLE=$(playerctl metadata --format "{{ title }}" )
    
    CURR=$(playerctl position | cut -d. -f1)
    TOT_US=$(playerctl metadata mpris:length)
    
    if [ -z "$TOT_US" ]; then
        echo "$TITLE [Live]"
        exit 0
    fi

    TOT=$((TOT_US / 1000000))
    
    DIFF=$((TOT - CURR))

    if [ $DIFF -lt 0 ]; then DIFF=0; fi

    MIN=$((DIFF / 60))
    SEC=$((DIFF % 60))
    
    printf "%s | -%02d:%02d\n" "$TITLE" "$MIN" "$SEC"
else
    echo ""
fi
