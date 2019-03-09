#!/usr/bin/env bash

# This script builds and this package and its dependencies with nix.
# please go to https://nixos.org/nix/ to install nix before running this

set -e

nix-build -I nixpkgs=channel:nixos-18.09 release0.nix
