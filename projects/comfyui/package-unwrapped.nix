{
  lib,
  python3,
  customNodesDrv,
  fetchFromGitHub,
  stdenv,
}: let
  pythonEnv = python3.withPackages (
    ps:
      (with ps; [
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
      ])
      ++ customNodesDrv.passthru.dependencies.pkgs or []
  );
in
  stdenv.mkDerivation {
    pname = "comfyui-unwrapped";
    version = "unstable-2024-09-18";

    src = fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "7183fd1665e88c13184a11d7ec06f56307b4fa7f";
      hash = "sha256-kap3fJObcqSGV7S4fJ+Yhg44vHjSkOLWKSuZdrAJf5E=";
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
      cp -r $src/utils $out/
      cp -r $src/*.py $out/
      echo "Copying executable script"
      echo "${pythonEnv}/bin/python $out/main.py \$@" > $out/bin/comfyui
      chmod +x $out/bin/comfyui
      cp -r $src/custom_nodes $out/
      substituteInPlace $out/server.py --replace-warn "from app.user_manager import UserManager" ""
      substituteInPlace $out/server.py --replace-warn "self.user_manager = UserManager()" \
        'logging.info("User Manager disabled: not applicable when using nix")'
      substituteInPlace $out/server.py --replace-warn "self.user_manager.add_routes(self.routes)" ""
      runHook postInstall
    '';

    passthru.python = pythonEnv;

    meta = with lib; {
      homepage = "https://github.com/comfyanonymous/ComfyUI";
      description = "The most powerful and modular stable diffusion GUI with a graph/nodes interface.";
      license = licenses.gpl3;
      platforms = platforms.all;
    };
  }
