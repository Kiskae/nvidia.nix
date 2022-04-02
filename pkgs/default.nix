{ lib, pkgs, callPackage, }:
let
  mapOutputs = drv: map
    (output: {
      name = "${drv.name}${lib.optionalString (output != "out") "-${output}"}";
      path = lib.getOutput output drv;
    })
    drv.outputs;
in
lib.recurseIntoAttrs (
  (callPackage ./nvidia-driver { }) //
  {
    driver-link = pkgs.runCommand "hardware-driver-link"
      {
        driverProvider = pkgs.libglvnd.driverLink;
      } ''
      ln -s $driverProvider $out
    '';
  }
)
