{
  fetchurl,
  fetchair,
  modelTypes,
  ecosystemOf,
  lib,
}: let
  # a fetcher that accepts an authToken and either an air or a url plus optional meta attrs
  fetchModel = {
    url ? null,
    air ? lib.throwIf (isNull url) "fetchModel: either url or air is required (sha256: ${sha256})" null,
    sha256,
    authToken ? null,
    type ? null,
    base ? null,
    ecosystem ? null,
  }: let
    warnUnused = attrs: let
      nonNull = lib.attrsets.filterAttrs (k: v: !isNull v) attrs;
    in
      lib.warnIfNot (nonNull == {})
      "fetchModel (air: ${air}): unused arguments: ${builtins.concatStringsSep ", " (builtins.attrNames nonNull)}";
    # generic name to keep resources content-addressed
    name = "resource";
    fetched =
      if isNull air && isNull url
      then lib.throw "fetchModel: choose one, not both:\nair: ${air}\nurl: ${url}"
      else if !isNull air
      then warnUnused {inherit ecosystem type;} (fetchair {inherit air sha256 authToken;})
      else if isNull authToken || authToken == ""
      then import <nix/fetchurl.nix> {inherit name url sha256;}
      else
        fetchurl {
          inherit name url sha256;
          curlOptsList = ["--header" "Authorization: Bearer ${authToken}"];
        };
  in
    lib.recursiveUpdate {meta = {inherit type base ecosystem;};} fetched;

  # using the AIR spec and observed patterns of comfyui model installations as reference
  dirModelTypeMap = {
    checkpoints = modelTypes.checkpoint;
    clip = modelTypes.embedding;
    clip_vision = modelTypes.embedding;
    controlnet = modelTypes.controlnet;
    diffusion_models = modelTypes.checkpoint;
    inpaint = modelTypes.checkpoint;
    ipadapter = modelTypes.controlnet;
    loras = modelTypes.lora;
    text_encoder = modelTypes.embedding;
    upscaler = modelTypes.upscaler;
    vae = modelTypes.vae;
  };
  typeFromInstallPath = path: dirModelTypeMap."${builtins.head (lib.splitString "/" path)}" or null;
in {
  inherit typeFromInstallPath;
  # declare models as simply as:
  # ```
  # "loras/example1.safetensors" = { air = "urn:air:flux1:lora:civitai:<id>@<version>"; sha256 = "<hash>"; };
  # "loras/example2.safetensors" = { file = inputs.my-lora-file; base = baseModels.sd15; };
  # "checkpoints/example3.safetensors" = { url = "..."; sha256 = "<hash>"; base = baseModels.flux1-s; };
  # ```
  # both AIR and sha256 is available on the civitai page of a model.
  # huggingface provides sha256 for a resource on its page.
  installModels = builtins.mapAttrs (
    installPath: {
      authToken ? null,
      file ? null,
      air ? null,
      url ? null,
      sha256 ?
        lib.throwIf (isNull file)
        "installModels (installPath: ${installPath}): sha256 is required for remote resources"
        null,
      type ? null,
      base ? null,
      ecosystem ? null,
    } @ args:
      if !isNull file # nothing to fetch
      then lib.attrsets.recursiveUpdate {meta = {inherit type ecosystem base;};} file
      else
        fetchModel (
          lib.optionalAttrs (isNull air) {
            type = typeFromInstallPath installPath;
            ecosystem = ecosystemOf base;
          }
          // args
        )
  );
}
