{ lib
, runCommand
, writeScript
, python3
}: rec {
  convertManifest = unpacked_binary: runCommand "convert-manifest" { inherit unpacked_binary; } ''
    ${python3}/bin/python3 ${./convert-manifest.py} "$unpacked_binary/.manifest" > $out
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
  variableDefinitions = { vars ? variables, baseIndex ? 1 }: lib.concatStringsSep "\n" (lib.imap0
    (
      i: var_name: "local ${var_name}=\$${toString (i + baseIndex)}"
    )
    vars);
  bashHandlerDefinition = { manifest, entryHandler }: writeScript "manifest-handler" ''
    manifest_entry () {
        ${variableDefinitions {}}

        # User code
        ${entryHandler}
    }

    source ${manifest}
  '';
}
