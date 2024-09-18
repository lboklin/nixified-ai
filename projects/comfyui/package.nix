{
  lib,
  writeTextFile,
  writeScriptBin,
  python3,
  comfyui-unwrapped,
  modelsDrv ? null,
  customNodesDrv ? null,
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
in
  executable
  // {
    passthru =
      builtins.trace customNodesDrv.outPath
      unwrappedWithDeps.passthru
      // {inherit customNodesDrv modelsDrv;};
  }
