{
  lib,
  linkFarm,
  comfyuiTypes,
  customNodes,
}: let
  t = lib.types // comfyuiTypes;

  # aggregate all custom nodes' dependencies
  dependencies =
    lib.foldlAttrs
    ({
      pkgs,
      models,
    }: _: x: {
      pkgs = pkgs ++ (x.dependencies.pkgs or []);
      models = models // (x.dependencies.models or {});
    })
    {
      pkgs = [];
      models = {};
    }
    customNodes;

  # create a derivation for our custom nodes
  customNodesDrv =
    linkFarm "comfyui-custom-nodes"
    # check that all nodes are of the expected type
    (lib.mapAttrs (name: t.expectType t.customNode "custom node \"${name}\"") customNodes);
in
  customNodesDrv // {passthru = {inherit dependencies;};}
