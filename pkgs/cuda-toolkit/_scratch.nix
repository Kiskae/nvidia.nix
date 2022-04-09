let
  toDebugPkg = pname: pkg:
    let
      src = srcOnly {
        name = "${pname}-${pkg.version}";
        src = (pkg.src.${system});
      };
      report = with pkgs; stdenvNoCC.mkDerivation {
        inherit pname src;
        inherit (pkg) version;
        buildInputs = [ patchelf bintools file ];
        builder = writeScript "stuff" ''
          source ${stdenvNoCC}/setup
          while IFS= read -r -d $'\0' path; do
            echo "=$path=" ;

            if file $path | grep -q 'dynamically linked'; then
              target=$out${"$"}{path#"$src"}
              mkdir -p "$target"
              patchelf --print-needed --print-soname $path > "$target/patchelf.txt" || echo "patchelf failed"
              ldd $path > "$target/ldd.txt" || echo "ldd failed"
              strings $path | grep '.*\.so' > "$target/strings.txt"
              grep -v -x -f "$target/patchelf.txt" "$target/strings.txt" > "$target/dy.txt" || echo "no dynamic libs found" 
            fi
          done < <(find $src -type f -print0)
        '';
      };
    in
    linkFarm "inspection-report" [
      { name = "source"; path = src; }
      { name = "report"; path = report; }
    ];
  debugFromManifest = manifest:
    let
      inherit (lib) filterAttrs mapAttrs;
    in
    (mapAttrs toDebugPkg (filterAttrs (_: pkg: pkg.src ? ${system}) manifest.pkgs)) //
    {
      recurseForDerivations = true;
    };
