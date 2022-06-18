#! /usr/bin/env nix-shell
#! nix-shell -i bash

NVIDIA_RELEASE_CHANNELS=http://people.freedesktop.org/~aplattner/nvidia-versions.txt
echo "f: ["

while IFS=" " read -r branch maturity version; do
echo "  (f \"$branch\" \"$maturity\" \"$version\")"
done < <(curl -L $NVIDIA_RELEASE_CHANNELS | grep "^[^#]")

echo "]"
