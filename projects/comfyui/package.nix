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
    text = lib.generators.toYAML {} ({
        comfyui = lib.optionalAttrs (!isNull customNodesDrv) {
          # base_path = basePath;
          custom_nodes = "${customNodesDrv}";
        };
      }
      // lib.optionalAttrs (!isNull modelsDrv) {
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
      });
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
      unwrappedWithDeps.passthru
      // {inherit customNodesDrv modelsDrv;};
  }
# stdenv.mkDerivation {
#   pname = "comfyui";
#   inherit (comfyui-unwrapped) version;
#   installPhase = ''
#     runHook preInstall
#     echo "Preparing bin folder"
#     mkdir -p $out/bin/
#     echo "Copying ${extraModelPathsYaml} to $out"
#     cp ${extraModelPathsYaml} $out/extra_model_paths.yaml
#     echo "Setting up custom nodes"
#     ${lib.optionalString (!isNull customNodesDrv) "ln -snf ${customNodesDrv} $out/custom_nodes"}
#     echo "Copying executable script"
#     cp ${executable}/bin/comfyui $out/bin/comfyui
#     runHook postInstall
#   '';
#   meta = with lib; {
#     homepage = "https://github.com/comfyanonymous/ComfyUI";
#     description = "The most powerful and modular stable diffusion GUI with a graph/nodes interface.";
#     license = licenses.gpl3;
#     platforms = platforms.all;
#   };
# }

