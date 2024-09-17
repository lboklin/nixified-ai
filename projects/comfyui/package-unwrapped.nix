{
  lib,
  python3,
  writers,
  fetchFromGitHub,
  stdenv,
  extraModelPathsYaml ? lib.generators.toYAML {} {},
  customNodesDrv ? null,
  basePath ? "/var/lib/comfyui",
  userPath ? "${basePath}/user",
}: let
  pythonEnv = python3.withPackages (ps:
    with ps;
      [
        aiohttp
        einops
        kornia
        pillow
        psutil
        pyyaml
        safetensors
        scipy
        spandrel
        torch
        torchsde
        torchvision
        torchaudio
        tqdm
        transformers
      ]
      ++ dependencies.pkgs);

  executable = writers.writeDashBin "comfyui" ''
    ${pythonEnv}/bin/python $out/comfyui
  '';
in
  stdenv.mkDerivation {
    pname = "comfyui";
    version = "unstable-2024-09-09";

    src = fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "cd4955367e4170b88ba839efccb6d2ed0dd963ad";
      hash = "sha256-oEjsPznZxfTxT+m7Uvbsn+/ZiNAROfeUQMHNgYOAkvU=";
    };

    installPhase = ''
      runHook preInstall
      echo "Preparing bin folder"
      mkdir -p $out/bin/
      echo "Copying comfyui files"
      # These copies everything over but test/ci/github directories.  But it's not
      # very future-proof.  This can lead to errors such as "ModuleNotFoundError:
      # No module named 'app'" when new directories get added (which has happened
      # at least once).  Investigate if we can just copy everything.
      cp -r $src/comfy $out/
      cp -r $src/comfy_execution $out/
      cp -r $src/comfy_extras $out/
      cp -r $src/model_filemanager $out/
      cp -r $src/api_server $out/
      cp -r $src/app $out/
      cp -r $src/web $out/
      cp -r $src/*.py $out/
      mv $out/main.py $out/comfyui
      echo "Copying ${extraModelPathsYaml} to $out"
      cp ${extraModelPathsYaml} $out/extra_model_paths.yaml
      echo "Setting up custom nodes"
      ${lib.optionalString (!isNull customNodesDrv) "ln -snf ${customNodesDrv} $out/custom_nodes"}
      echo "Copying executable script"
      cp ${executable}/bin/comfyui $out/bin/comfyui
      substituteInPlace $out/bin/comfyui --replace-warn "\$out" "$out"
      echo "Patching python code..."
      substituteInPlace $out/folder_paths.py --replace-warn "if not os.path.exists(input_directory):" "if False:"
      substituteInPlace $out/folder_paths.py --replace-warn 'os.path.join(os.path.dirname(os.path.realpath(__file__)), "user")' '"${userPath}"'
      runHook postInstall
    '';

    meta = with lib; {
      homepage = "https://github.com/comfyanonymous/ComfyUI";
      description = "The most powerful and modular stable diffusion GUI with a graph/nodes interface.";
      license = licenses.gpl3;
      platforms = platforms.all;
    };
  }
