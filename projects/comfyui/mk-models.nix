# creates a derivation for a model set
{
  lib,
  models,
  linkFarm,
  comfyuiTypes,
  mapCompatModelInstall,
}: let
  t = lib.types // comfyuiTypes;

  modelsDrv = let
    modelEntryF = mapCompatModelInstall (attrName: model: {
      name = t.expectType t.installPath "attribute name of model" attrName;
      path = t.expectType t.model "model resource for \"${attrName}\"" model;
    });
  in
    linkFarm "comfyui-models"
    (lib.mapAttrsToList modelEntryF
      (lib.warnIf (models == {})
        "No models to install - the potential enjoyment you may derive from this ComfyUI setup will be limited"
        models));
in
  modelsDrv
