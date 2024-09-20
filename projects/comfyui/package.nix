{
  lib,
  writeTextFile,
  writeScriptBin,
  stdenv,
  python3,
  comfyui-unwrapped,
  mkModels,
  mkCustomNodes,
  modelsDrv ? null,
  customNodesDrv ? null,
  customNodePkgs ? {},
  basePath ? "/var/lib/comfyui",
  inputPath ? "${basePath}/input",
  outputPath ? "${basePath}/output",
  tempPath ? "${basePath}/temp",
  userPath ? "${basePath}/user",
  extraArgs ? [],
}: let
  unwrappedWithDeps = comfyui-unwrapped.override {
    inherit python3 customNodesDrv;
  };

  extraModelPathsYaml = writeTextFile {
    name = "extra_model_paths.yaml";
    text =
      lib.generators.toYAML {}
      (lib.attrsets.recursiveUpdate
        (lib.optionalAttrs (!isNull customNodesDrv) {
          comfyui = {
            base_path = basePath;
            custom_nodes = customNodesDrv;
          };
        })
        (lib.optionalAttrs (!isNull modelsDrv) {
          comfyui = let
            pathMap = path: rec {
              name = lib.pipe path [
                (lib.strings.replaceStrings ["${modelsDrv}/"] [""])
                lib.strings.unsafeDiscardStringContext
                (lib.splitString "/")
                builtins.head
              ];
              value = modelsDrv + "/${name}";
            };
            subdirs = builtins.map pathMap (lib.filesystem.listFilesRecursive modelsDrv);
          in
            builtins.listToAttrs subdirs;
        }));
  };
  executable = writeScriptBin "comfyui" ''
    ${unwrappedWithDeps}/bin/comfyui \
      --input-directory ${inputPath} \
      --output-directory ${outputPath} \
      --temp-directory ${tempPath} \
      --user-directory ${userPath} \
      --extra-model-paths-config ${extraModelPathsYaml} \
      ${builtins.concatStringsSep " \\\n  " (extraArgs ++ ["$@"])}
  '';
  comfyui = stdenv.mkDerivation (finalAttrs: {
    name = "comfyui";
    src = executable;
    buildPhase = ''
      mkdir -p $out/bin
      cp $src/bin/comfyui $out/bin/
    '';
    passthru = {
      withModels = modelInstalls: finalAttrs.override {modelsDrv = mkModels modelInstalls;};
      withCustomNodes = f: finalAttrs.override {customNodesDrv = mkCustomNodes (f customNodePkgs);};
    };
  });
in
  comfyui.overrideAttrs
  {passthru = lib.recursiveUpdate unwrappedWithDeps.passthru {inherit customNodesDrv modelsDrv;};}
