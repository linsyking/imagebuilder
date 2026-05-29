#!/bin/bash

set -e

if ! command -v nixos-rebuild >/dev/null 2>&1; then
    echo "nixos-rebuild is required but it's not installed. Aborting."
    exit 1
fi

sudo mkdir -p /etc/nixos

if [ ! -f /etc/nixos/configuration.nix ]; then
    sudo cp /scripts/nixos-configuration.nix /etc/nixos/configuration.nix
fi

sudo nixos-rebuild switch
