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
    ]
    [
      "meson"
      "compile"
      "-C"
      "@buildDirectory@"
      "helios_d3d12_static"
    ]
  ];
  requirements = [
    "LLVM-22.1.8-clang-cl-lld-link"
    "MSVC-v143"
    "SDK-10.0.26100.0"
    "dxil-spirv-at-paired-pin"
    "fixed-SPIRV-Tools"
  ];
  outputs = [
    "libs/d3d12core/libhelios_d3d12_static.a"
    "shader-libraries"
    "pdb"
  ];
}
