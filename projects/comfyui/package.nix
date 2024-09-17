{
  lib,
  python3,
  writeTextFile,
  writeScriptBin,
  callPackage,
  modelsDrv ? null,
  customNodesDrv ? null,
  basePath ? "/var/lib/comfyui",
  inputPath ? "${basePath}/input",
  outputPath ? "${basePath}/output",
  tempPath ? "${basePath}/temp",
  userPath ? "${basePath}/user",
  extraArgs ? [],
}: let
  extraModelPathsYaml = writeTextFile {
    name = "extra_model_paths.yaml";
    text = lib.generators.toYAML {} (lib.optionalAttrs (!isNull modelsDrv) {
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
        lib.traceValSeq (builtins.listToAttrs subdirs);
    });
  };
  comfyui = callPackage ./package-unwrapped.nix {
    inherit
      python3
      customNodesDrv
      extraModelPathsYaml
      userPath
      ;
  };
in
  writeScriptBin "comfyui" ''
    ${comfyui}/bin/comfyui \
      --input-directory ${inputPath} \
      --output-directory ${outputPath} \
      --extra-model-paths-config ${extraModelPathsYaml} \
      --temp-directory ${tempPath} \
      ${builtins.concatStringsSep " \\\n  " (extraArgs ++ ["$@"])}
  ''
