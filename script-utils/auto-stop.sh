#!/usr/bin/env bash


containerIDs=$(docker container ls --filter "label=at.grub1.auto-stop" --quiet | \
    tr '\n' ' ')

docker container stop $containerIDs

