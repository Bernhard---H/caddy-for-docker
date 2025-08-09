#!/usr/bin/env bash


containerIDs=$(docker container ls --filter "label=at.grub1.auto-stop" --quiet | tr '\n' ' ')

if [[ -n $containerIDs ]]; then
    docker container stop $containerIDs
fi

