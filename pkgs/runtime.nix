{ lib, stdenvNoCC, runCommand, addOpenGLRunpath }:
let
  runtime-driver = runCommand "nvidia-runtime"
    {
      provider = addOpenGLRunpath.driverLink;
    } ''
    ln -s $provider $out
  '';
  defineRuntimeLib = lib.makeOverridable (
    { pname
    , version
    , provider ? runtime-driver
    }: stdenvNoCC.mkDerivation {
      inherit pname provider;
      version = toString version;

      buildCommand = ''
        mkdir -p $out/lib
        ln -s $provider/lib/$pname.so.$version $out/lib
        ln -s -T $provider/lib/$pname.so.$version $out/lib/$pname.so
      '';
    }
  );
in
{
  libnvidia-ml = defineRuntimeLib {
    pname = "libnvidia-ml";
    version = 1;
  };
}
