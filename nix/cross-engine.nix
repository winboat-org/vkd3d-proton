{
  pkgs,
  sources,
  dependencies,
  target,
  configuration,
}:
let
  architecture = if target == "engine-x86" then "x86" else "x64";
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
pkgs.runCommand "helios-vkd3d-msvc-cross-${architecture}-${configuration}"
  {
    nativeBuildInputs = [
      pkgs.meson
      pkgs.ninja
      pkgs.pkg-config
      pkgs.glslang
      dependencies.hostWidl
      pkgs.stdenv.cc
      pkgs.llvmPackages_22.lld
      pkgs.llvmPackages_22.llvm
      (pkgs.python3.withPackages (p: [ p.jinja2 ]))
    ];
    env.LIB = pkgs.lib.concatStringsSep ";" (
      map (path: "${dependencies.msvcSysroot}/${path}/${architecture}") [
        "crt/lib"
        "sdk/lib/ucrt"
        "sdk/lib/um"
      ]
    );
  }
  ''
    cp -R ${sources.vkd3d-proton} source
    chmod -R u+w source
    patchShebangs source
    meson setup build source --wrap-mode=nodownload \
      --cross-file ${dependencies.msvcCrossFile} \
      --buildtype ${if configuration == "debug" then "debug" else "release"} \
      -Db_vscrt=mt -Denable_tests=false '-Dc_args=/Z7 -Wno-error=incompatible-pointer-types'
    meson compile -C build -j "$NIX_BUILD_CORES" \
      helios_d3d12_static vkd3d-proton vkd3d-shader vkd3d_common dxil-spirv dxbc_spv_module dxbc_spv
    ${pkgs.lib.concatMapStringsSep "\n" (archive: ''
      mkdir -p "$out/$(dirname '${archive}')"
      cp 'build/${archive}' "$out/${archive}"
    '') archives}
    find build -type f -name '*.h' | while IFS= read -r header; do
      relative="''${header#build/}"
      mkdir -p "$out/$(dirname "$relative")"
      cp "$header" "$out/$relative"
    done
    mkdir -p "$out/licenses/vkd3d-proton" "$out/share/winboat"
    cp -R ${dependencies.msvcSysroot}/share/licenses/. "$out/licenses/"
    cp -R ${dependencies.hostWidl}/share/licenses/. "$out/licenses/"
    find ${sources.vkd3d-proton} -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'NOTICE*' \) \
      | while IFS= read -r notice; do
        relative="''${notice#${sources.vkd3d-proton}/}"
        mkdir -p "$out/licenses/vkd3d-proton/$(dirname "$relative")"
        cp "$notice" "$out/licenses/vkd3d-proton/$relative"
      done
    cp build/compile_commands.json "$out/share/winboat/compile_commands.json"
    python3 ${dependencies.msvcInspector} "$out" ${pkgs.llvmPackages_22.llvm}/bin/llvm-readobj \
      --architecture=${architecture} > "$out/images.json"
  ''
