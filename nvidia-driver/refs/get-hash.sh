#! /usr/bin/env bash

nix-prefetch-url $@ | xargs nix hash to-sri --type sha256