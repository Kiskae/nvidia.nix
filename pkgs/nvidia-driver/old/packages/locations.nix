{ lib
, codegen
, toScript
  # CodeGen -> derivation
}:
let
  inherit (codegen) ifExpr;
  compileToScript =
    let
      inherit (codegen) concatOutput mkRegularVar fromCode;
      inherit (lib) mapAttrsToList;
      # 
      vars = lib.genAttrs
        [
          "prefix"
          "dir"
          "ln_override"
        ]
        mkRegularVar;
      ruleToCodeGen = rule: lib.pipe rule [
        (x: removeAttrs x [ "check" ])
        (mapAttrsToList (n: vars.${n}.set))
        # [ CodeGen ]
        concatOutput
        # CodeGen (onPass)
        (x: rule.check x (fromCode ":"))
        # CodeGen
      ];
    in
    rules: lib.pipe rules [
      # [ Rule ]
      (map ruleToCodeGen)
      # [ CodeGen ]
      (rules: concatOutput (
        # include var prelude before the rules
        (mapAttrsToList (_: v: v.prelude) vars)
        ++ [
          # default location for most fules
          (vars.prefix.set "$outputLib")
          (vars.dir.set "/lib")
        ]
        ++ rules
      ))
      # CodeGen
      toScript
      # derivation
    ];

  matchVar =
    let
      inherit (codegen) ifExpr;
    in
    var: value: ifExpr "${var} == ${value}";
  matchType = matchVar "$type";
  matchClassifier = matchVar "$classifier";
in
compileToScript [
  {
    check = matchVar "$arch" "COMPAT32";
    prefix = "lib32";
  }
  {
    check = matchType "MANPAGE";
    prefix = "$outputMan";
    dir = "/share/man";
  }
  {
    check = matchType "XORG_OUTPUTCLASS_CONFIG";
    dir = "/share/X11/xorg.conf.d";
  }
  {
    check = matchType "GLVND_EGL_ICD_JSON";
    dir = "/share/glvnd/egl_vendor.d";
  }
  {
    check = matchType "GBM_BACKEND_LIB_SYMLINK";
    dir = "/lib/gbm";
    # either link to $allocator or $lib
    ln_override = "$''{allocator:-$''{!outputLib}}/lib";
  }
  {
    check = matchType "VULKAN_ICD_JSON";
    dir = "/share/vulkan";
  }
  {
    check = matchType "*_BIN*";
    prefix = "$outputBin";
    dir = "/bin";
  }
  {
    check = matchClassifier "kmod";
    dir = "/.";
  }
  {
    check = matchClassifier "xorg.modules";
    dir = "/lib/xorg/modules";
  }
]
