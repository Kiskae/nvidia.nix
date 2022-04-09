{ lib
, vars
  # mapping of manifest values to shell variables
, matchVariable
  # string -> string -> CLS
, matchVariableMany
  # string -> [ string ] -> CLS
, matchAll
  # [ CLS ] -> CLS
, matchAny
  # [ CLS ] -> CLS
, invert
  # CLS -> CLS
, globalIntercept ? (lib.const lib.id)
  # [ string ] -> CLS -> CLS
, isClassifier
  # CLS -> bool
}:
let
  mapToClassifiers =
    let
      f = path: lib.mapAttrs (n: v:
        let
          new_path = path ++ [ n ];
          next = x: matchAny (f new_path x);
        in
        if isClassifier v
        then globalIntercept new_path v
        else next v
      );
    in
    f [ ];
  match =
    let
      inherit (lib) genAttrs mapAttrs const;
      many = mapAttrs (const matchVariableMany) vars;
    in
    (mapAttrs (const matchVariable) vars) // { inherit many; };
in
mapToClassifiers {
  kmod = match.many.type [
    "KERNEL_MODULE_*"
    "UVM_MODULE_*"
  ];
  xorg = {
    modules = {
      driver = match.type "XMODULE_*";
      glx_module = match.type "GLX_MODULE_*";
      xvmc = match.type "XLIB_*";
      legacy = match.type "XFREE86_*";
    };
    drm_conf = match.type "XORG_OUTPUTCLASS_CONFIG";
  };
  drivers = {
    glvnd = matchAny {
      drivers = match.many.target_path [
        "libGLX_nvidia.so.*"
        "libEGL_nvidia.so.*"
        "libGLX_indirect.so.0"
        "libGLESv2_nvidia.so.*"
        "libGLESv1_CM_nvidia.so.*"
      ];
      icd = match.type "GLVND_EGL_ICD_JSON";
    };

    vdpau = matchAll [
      (match.type "VDPAU_*")
      # some distributions include the vdpau vendor-neutral libs
      (invert (match.type "VDPAU_WRAPPER_*"))
    ];

    libnvidia-tls = match.type "TLS_*";

    gbm_backend = match.type "GBM_BACKEND_LIB_SYMLINK";

    vulkan_json = match.type "VULKAN_ICD_JSON";

    internal = match.many.target_path [
      "libnvidia-cbl*"
      "libnvidia-cfg*"
      "libnvidia-compiler*"
      "libnvidia-eglcore*"
      "libnvidia-glcore*"
      "libnvidia-glsi*"
      "libnvidia-glvkspirv*"
      "libnvidia-rtcore*"
      "libnvidia-allocator*"
      # not explicitly listed?
      "libnvidia-vulkan-producer*"
    ];
  };
}
