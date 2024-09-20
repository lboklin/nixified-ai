{
  config,
  lib,
  ...
}: let
  l = lib // config.flake.lib;
  inherit (config.flake) overlays;
in {
  perSystem = {
    config,
    pkgs,
    lib,
    self',
    ...
  }: let
    commonOverlays = [
      (final: prev: {
        opencv-python-headless = final.opencv-python;
        opencv-python = final.opencv4;
      })
      (l.overlays.callManyPackages [
        ../../packages/mediapipe
        ../../packages/gguf
        ../../packages/spandrel
        ../../packages/colour-science
        ../../packages/rembg
        ../../packages/pixeloe
      ])
      # what gives us a python with the overlays actually applied
      overlays.python-pythonFinal
    ];

    python3Variants = {
      amd = l.overlays.applyOverlays pkgs.python311Packages (commonOverlays
        ++ [
          overlays.python-torchRocm
        ]);
      nvidia = l.overlays.applyOverlays pkgs.python311Packages (commonOverlays
        ++ [
          # FIXME: temporary standin for practical purposes.
          # They're prebuilt and come with cuda support.
          (final: prev: {
            torch = prev.torch-bin;
            torchaudio = prev.torchaudio-bin;
            torchvision = prev.torchvision-bin;
          })
          # use this when things stabilise and we feel ready to build the whole thing
          # overlays.python-torchCuda
        ]);
    };

    inherit (self'.legacyPackages.air) fetchair modelTypes ecosystemOf ecosystems baseModels;
    comfyuiTypes = import ./types.nix {inherit lib;};
    modelInstallers = import ./model-installers.nix {
      inherit lib fetchair ecosystemOf modelTypes;
      inherit (pkgs) fetchurl;
    };
    inherit (modelInstallers) installModels;

    mkModels = import ./mk-models.nix {
      inherit lib comfyuiTypes;
      inherit (pkgs) linkFarm;
    };
    mkCustomNodes = import ./mk-custom-nodes.nix {
      inherit lib comfyuiTypes;
      inherit (pkgs) linkFarm;
    };

    # gpu-dependent packages
    pkgsFor = vendor: let
      python3Packages = python3Variants."${vendor}";
      python3 = python3Packages.python;
    in
      rec {
        # make available the python package set used so that user-defined custom nodes can depend on it
        inherit mkCustomNodes mkModels python3Packages;

        comfyui-unwrapped = pkgs.callPackage ./package-unwrapped.nix {
          inherit python3;
          customNodesDrv = mkCustomNodes {};
        };
        comfyui = pkgs.callPackage ./package.nix {inherit comfyui-unwrapped mkModels mkCustomNodes python3;};
      }
      # include all other packages as well to make it more convenient
      // builtins.removeAttrs self'.legacyPackages.comfyuiPackages ["amd" "nvidia"];
    amd = pkgsFor "amd";
    nvidia = pkgsFor "nvidia";
  in {
    legacyPackages.comfyuiPackages = {
      inherit
        amd
        nvidia
        installModels
        modelTypes
        ecosystems
        baseModels
        ;
      types = comfyuiTypes;
      inherit
        (comfyuiTypes)
        isModel
        isCustomNode
        ;
    };

    packages = {
      comfyui-amd = amd.comfyui;
      comfyui-nvidia = nvidia.comfyui;
    };
  };
}
