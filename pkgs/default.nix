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
    runtime = lib.recurseIntoAttrs (callPackage ./alternatives { });
  }
)
