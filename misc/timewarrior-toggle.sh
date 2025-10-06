#!/bin/env bash

msg=""

if timew :quiet; then
    # Clock running
    timew stop :quiet
    msg="punch OUT"
else
    # Clock stopped
    timew start :quiet
    msg="punch IN"
fi

notify-send -a clock -e "$msg"
