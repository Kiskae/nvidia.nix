{ lib }: rec {
  mkManifestWith = pkgs: src: with pkgs; runCommand "manifest.sh" { inherit src; } ''
    if [ ! -f "$src/.manifest" ]; then
      echo "$src is not an nvidia-installer distribution"
      exit 1
    fi

    ${python3}/bin/python3 ${./convert-manifest.py} "$src/.manifest" > $out
  '';
  variables = [
    "src_path"
    "target_path"
    "perms"
    "type"
    "module"
    "arch"
    "extra"
  ];
  mkScriptTemplate = action: manifest: ''
    manifest_entry() {
      ${lib.concatImapStringsSep "\n" (i: v: "local ${v}=\$${toString i}") variables}

      ${action}
    }

    source ${manifest}
  '';
}
