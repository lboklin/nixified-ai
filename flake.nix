{
  nixConfig = {
    extra-substituters = [ "https://ai.cachix.org" ];
    extra-trusted-public-keys = [ "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc=" ];
  };

  description = "A Nix Flake that makes AI reproducible and easy to run";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/2fd19c8be2551a61c1ddc3d9f86d748f4db94f00";
    };
    nixified-cfg = {
      url = "github:lboklin/nixified-cfg/comfyui-krita-requirements";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    invokeai-src = {
      url = "github:invoke-ai/InvokeAI/v3.3.0post3";
      flake = false;
    };
    textgen-src = {
      url = "github:oobabooga/text-generation-webui/v1.7";
      flake = false;
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    hercules-ci-effects = {
      url = "github:hercules-ci/hercules-ci-effects";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { flake-parts, invokeai-src, hercules-ci-effects, nixified-cfg, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      perSystem = { system, ... }: {
        _module.args = let
          pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in {
          inherit pkgs;
          comfyuiCfg = nixified-cfg.cfg.comfyui system;
        };
        legacyPackages = {
          koboldai = builtins.throw ''


                   koboldai has been dropped from nixified.ai due to lack of upstream development,
                   try textgen instead which is better maintained. If you would like to use the last
                   available version of koboldai with nixified.ai, then run:

                   nix run github:nixified.ai/flake/0c58f8cba3fb42c54f2a7bf9bd45ee4cbc9f2477#koboldai
          '';
        };
      };
      systems = [
        "x86_64-linux"
      ];
      debug = true;
      imports = [
        ./checks
        hercules-ci-effects.flakeModule
#        ./modules/nixpkgs-config
        ./overlays
        ./projects/comfyui
        ./projects/invokeai
        ./projects/textgen
        ./website
      ];
    };
}
