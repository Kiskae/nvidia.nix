{ lib, stdenvNoCC, runCommand, python3, jq, src, buildCompat32 ? false }:
let
  inherit (src) version;

  manifest = runCommand "manifest"
    {
      inherit src;
    } ''
    if [ ! -f "$src/.manifest" ]; then
      echo "$src is not an nvidia-installer distribution"
      exit 1
    fi

    mkdir $out
    ${lib.getExe python3} ${./parse-manifest.py} \
      --entries "$out/manifest.json" \
      --header "$out/header.json" \
      "$src/.manifest"
  '';

  filterManifest = filterDefinition: runCommand "filtered-manifest"
    {
      inherit manifest filterDefinition;
      passAsFile = [ "filterDefinition" ];
      nativeBuildInputs = [ jq ];
    }
    ''
      install -D -T $filterDefinitionPath $out/filter.jq
      jq -f $out/filter.jq \
          --slurpfile header $manifest/header.json \
          $manifest/manifest.json \
          > $out/entries.json
    '';

  compileDefinition = pname:
    { filter
    , meta ? { }
    }: filterManifest ''
      def basename: split("/") | last;
      select(.entry | [${filter}] | any)
    '';
  classifierFilter =
    let
      markByFilter = pname: { filter, ... }: ''
        mark(.entry | [
          ${filter}
        ] | any; "${pname}")'';
    in
    pkgDefs: filterManifest (lib.concatStringsSep "\n|\n" ([
      ''
        def mark(f; $name): if [f] | any then .match |= . + [$name] else . end;
        def basename: split("/") | last;
        .''
    ] ++ (lib.mapAttrsToList markByFilter pkgDefs)));

  processDefinitions = pkgDefs: lib.mapAttrs compileDefinition pkgDefs // {
    inherit src manifest;
    fullData = classifierFilter pkgDefs;
  };

  versionAtLeast = lib.versionAtLeast version;
  versionOlder = lib.versionOlder version;

  kmodDefinition = { srcTree, ... } @ args: removeAttrs args [ "srcTree" ] // {
    filter = ''select(.file_path | ${srcTree}) | .type | startswith(
      "KERNEL_MODULE_", 
      "UVM_MODULE_",
      "DKMS_CONF"
    )'';
  };
in
processDefinitions {
  egl_platform_gbm = {
    filter = ''.type == "EGL_EXTERNAL_PLATFORM_JSON" and (.file_path | contains("_gbm"))'';
    meta.broken = versionOlder "495.29.05";
  };

  egl_platform_wayland = {
    filter = ''.type == "EGL_EXTERNAL_PLATFORM_JSON" and (.file_path | contains("_wayland"))'';
    meta.broken = versionOlder "378.09";
  };

  firmware = {
    filter = ''.type == "FIRMWARE"'';
    meta = {
      license = lib.licenses.unfreeRedistributableFirmware;
      sourceProvenance = lib.sourceTypes.binaryFirmware;
      broken = versionOlder "465.19.01";
    };
  };

  html-docs = {
    filter = ''.path == "NVIDIA_GLX-1.0/html"'';
  };

  kmod-open = kmodDefinition {
    srcTree = ''startswith("kernel-open/")'';
    meta.broken = versionOlder "515.43.04";
  };

  kmod-unfree = kmodDefinition {
    srcTree = ''startswith("\($header[0].kernel_module_build_dir)/")'';
  };

  libcuda = {
    filter = ''.file_path | basename | startswith("libcuda")'';
  };

  libglvnd_install_checker = {
    filter = ''.file_path | startswith("libglvnd_install_checker")'';
    meta.broken = true;
  };

  libnvcuvid = {
    filter = ''.file_path | basename | startswith("libnvcuvid")'';
    meta.broken = versionOlder "260.19.04";
  };

  libnvidia-allocator = {
    filter = ''.module == "nvalloc"'';
    # nvidia-drm_gbm.so added in 495.29.05
  };

  libnvidia-cfg = {
    filter = ''.file_path | basename | startswith("libnvidia-cfg")'';
  };

  libnvidia-egl-gbm = {
    filter = ''.file_path | basename | startswith("libnvidia-egl-gbm")'';
    meta.broken = versionOlder "495.29.05";
  };

  libnvidia-egl-wayland = {
    filter = ''.file_path | basename | startswith("libnvidia-egl-wayland")'';
    meta.broken = versionOlder "378.09";
  };

  libnvidia-encode = {
    filter = ''.type | startswith("ENCODEAPI_")'';
    # meta.broken = versionOlder "346.16";
  };

  libnvidia-fbc = {
    filter = ''.file_path | basename | startswith("libnvidia-fbc")'';
    meta.broken = versionOlder "331.17";
  };

  libnvidia-ifr = {
    filter = ''.type | startswith("NVIFR_")'';
    meta.broken = versionOlder "319.49" || versionAtLeast "495.29.05";
  };

  libnvidia-ml = {
    filter = ''.file_path | basename | startswith("libnvidia-ml")'';
  };

  libnvidia-opencl = {
    filter = ''.file_path | basename | startswith("libnvidia-opencl")'';
  };

  libnvidia-opticalflow = {
    filter = ''.module == "opticalflow"'';
    meta.broken = versionOlder "418.30";
  };

  libnvidia-rtcore = {
    filter = ''.module == "raytracing"'';
    meta.broken = versionOlder "410.57";
    # includes libnvidia-cbl < 495
  };

  libnvidia-tls = {
    filter = ''.type | startswith("TLS_")'';
  };

  libnvoptix = {
    filter = ''.module == "optix"'';
    meta.broken = versionOlder "410.57";
  };

  libOpenCL = {
    filter = ''.file_path | basename | startswith("libOpenCL")'';
  };

  libvdpau = {
    filter = ''.type | startswith("VDPAU_WRAPPER_")'';
    meta.broken = versionOlder "180.22" || versionAtLeast "361.16";
  };

  libvdpau_nvidia = {
    filter = ''.file_path | basename | startswith("libvdpau_nvidia.so")'';
    meta.broken = versionOlder "180.22";
  };

  opencl_icd = {
    filter = ''.type == "CUDA_ICD"'';
  };

  nvidia-application-profile = {
    filter = ''.type == "APPLICATION_PROFILE"'';
  };

  nvidia-bug-report = {
    filter = ''.file_path | startswith(
      "nvidia-bug-report",
      "nvidia-debugdump"
    )'';
  };

  nvidia-cuda-mps = {
    filter = ''.file_path | basename | startswith("nvidia-cuda-mps-")'';
  };

  __nvidia-installer = {
    filter = ''.file_path, .ln_target // "" | startswith("nvidia-installer")'';
    meta.broken = true;
  };

  __nvidia-modprobe = {
    filter = ''.file_path | startswith("nvidia-modprobe")'';
    meta.broken = true;
  };

  nvidia-persistenced = {
    filter = ''.file_path | startswith("nvidia-persistenced")'';
    meta.broken = versionOlder "319.17";
  };

  nvidia-powerd = {
    filter = ''.module == "powerd"'';
    meta.broken = versionOlder "510.39.01";
  };

  nvidia-settings = {
    filter = ''.file_path | startswith(
      "nvidia-settings",
      "libnvidia-gtk",
      "libnvidia-wayland-client"
    )'';
  };

  nvidia-sleep = {
    filter = ''([
      (.file_path | startswith("systemd/")),
      (.type | startswith("SYSTEMD_"))
    ] | any) and (.module == "installer")'';
    # might be wrong
    # meta.broken = versionOlder "465.19.01";
  };

  nvidia-smi = {
    filter = ''.file_path | startswith("nvidia-smi")'';
  };

  nvidia-xconfig = {
    filter = ''.file_path | startswith("nvidia-xconfig")'';
  };

  supported-gpus = {
    filter = ''.path == "NVIDIA_GLX-1.0/supported-gpus"'';
    meta.broken = versionOlder "450.51";
  };

  wine_dll = {
    filter = ''.type == "WINE_LIB"'';
    meta.broken = versionOlder "470.42.01";
  };

  xserver = {
    filter = ''.type | startswith(
      "XMODULE_",
      "GLX_MODULE_",
      "XLIB_",
      "XFREE86_",
      "XORG_"
    )'';
  };
}
