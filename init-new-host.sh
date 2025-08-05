#!/usr/bin/env bash

docker network create --driver bridge --subnet "10.17.0.0/16" --gateway "10.17.255.254" --ipv6=false caddy

