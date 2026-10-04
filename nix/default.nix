{
  pkgs,
  sources,
  dependencies ? { },
  target ? "engine-x64",
  configuration ? "release",
  toolchain ? { },
  schemaVersion ? 1,
}:
assert toolchain == { };
assert schemaVersion == 1 && (target == "engine-x64" || target == "engine-x86");
let
  archives = [
    "libs/d3d12core/libhelios_d3d12_static.a"
    "libs/vkd3d/libvkd3d-proton.a"
    "libs/vkd3d-shader/libvkd3d-shader.a"
    "libs/vkd3d-common/libvkd3d_common.a"
    "subprojects/dxil-spirv/libdxil-spirv.a"
    "subprojects/dxil-spirv/libdxbc_spv_module.a"
    "subprojects/dxil-spirv/subprojects/dxbc-spirv/libdxbc_spv.a"
  ];
in
if dependencies ? msvcCrossFile then
  import ./cross-engine.nix {
    inherit
      pkgs
      sources
      dependencies
      target
      configuration
      ;
  }
else
  {
    backend = "devbox";
    purpose = "build";
    abi = "msvc";
    crt = "mt";
    architecture = if target == "engine-x86" then "x86" else "x64";
    nativeFile = if target == "engine-x86" then ./clang-cl-x86.ini else ./clang-cl-x64.ini;
    commands = [
      [
        "meson"
        "setup"
        "@buildDirectory@"
        "@sourceDirectory@"
        "--wrap-mode=nodownload"
        "--buildtype"
        (if configuration == "debug" then "debug" else "release")
        "--native-file"
        "@nativeFile@"
        "-Db_vscrt=mt"
        "-Denable_tests=false"
        "-Dc_args=/Z7 -Wno-error=incompatible-pointer-types"
        "-Dcpp_args=/Z7 /D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH"
      ]
      [
        "meson"
        "compile"
        "-C"
        "@buildDirectory@"
        "helios_d3d12_static"
        "vkd3d-proton"
        "vkd3d-shader"
        "vkd3d_common"
        "dxil-spirv"
        "dxbc_spv_module"
        "dxbc_spv"
      ]
    ];
    requirements = [
      "LLVM-22.1.8-clang-cl-lld-link"
      "MSVC-v143"
      "SDK-10.0.26100.0"
      "dxil-spirv-at-paired-pin"
      "fixed-SPIRV-Tools"
    ];
    # Measured native MSVC archive: the core includes every dependency member
    # plus its three entry/debug members. Keep the individual archives too for
    # complete shader provenance; a second merge would duplicate the union.
    outputs = archives;
  }
