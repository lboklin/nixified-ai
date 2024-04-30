{ config, lib, options, pkgs, ...}:

with lib;

let
  cfg = config.services.comfyui;
  defaultUser = "comfyui";
  defaultGroup = defaultUser;
  service-name = "comfyui";
  mkComfyUIPackage = cfg: cfg.package.override {
    inputPath = "${cfg.dataPath}/input";
    outputPath = "${cfg.dataPath}/output";
    customNodes = cfg.customNodes;
    models = cfg.models;
  };
in
{
  options = {
    services.comfyui = {
      enable = mkEnableOption
        ("The most powerful and modular stable diffusion GUI with a graph/nodes interface.");

      dataPath = mkOption {
        type = types.str;
        default = "/var/lib/${service-name}";
        description = "path to the folders which stores models, custom nodes, input and output files";
      };

      cudaSupport = mkOption {
        type = types.bool;
        default = config.cudaSupport;
        description = "Whether or not to enable CUDA for NVidia GPU acceleration.";
        defaultText = literalExpression "config.cudaSupport";
        example = literalExpression "true";
      };

      rocmSupport = mkOption {
        type = types.bool;
        default = config.rocmSupport;
        description = "Whether or not to enable ROCM for ATi GPU acceleration.";
        defaultText = literalExpression "config.rocmSupport";
        example = literalExpression "true";
      };

      package = mkOption {
        type = types.package;
        default = (
          if config.cudaSupport
          then pkgs.comfyui-cuda
          else if config.rocmSupport
          then pkgs.comfyui-rocm
          else builtins.throw "can not choose a default package because neither config.cudaSupport nor config.rocmSupport are enabled"
        );
        defaultText = "Either comfyui-cuda or comfyui-rocm depending on whether cudaSupport or rocmSupport is enabled";
        example = literalExpression "pkgs.comfyui-rocm";
        description = "ComfyUI base package to use";
      };

      user = mkOption {
        type = types.str;
        default = defaultUser;
        example = "yourUser";
        description = ''
          The user to run ComfyUI as.
          By default, a user named `${defaultUser}` will be created whose home
          directory will contain input, output, custom nodes and models.
        '';
      };

      group = mkOption {
        type = types.str;
        default = defaultGroup;
        example = "yourGroup";
        description = ''
          The group to run ComfyUI as.
          By default, a group named `${defaultUser}` will be created.
        '';
      };

      useCPU = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Uses the CPU for everything. Very slow, but needed if there is no hardware acceleration.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 8188;
        description = "Set the listen port for the Web UI and API.";
      };

      customNodes = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "custom nodes to add to the ComfyUI setup. Expects a list of packages from pkgs.comfyui-custom-nodes";
      };

      listen = mkOption {
        # TODO: Use a net mask, if such a type exists.
        type = types.str;
        # Assume a higher security posture by default.
        default = "127.0.0.1";
        description = "The net mask to listen to.";
        example = "0.0.0.0";
      };

      cors-origin-domain = mkOption {
        # TODO: Use a CORS "domain", which is a hostname + a port.  It might
        # also include IPs and a port.  The port is required per CORS.
        type = types.str;
        default = "disabled";
        description = ''The CORS domain to bless.  Use "disabled" to disable.  This must include a port'';
        example = "foo.com:443";
      };

      cuda-malloc = mkOption {
        type = types.bool;
        # TODO: Verify this works.
        default = cfg.cudaSupport;
      };

      max-upload-size = mkOption {
        type = types.nullOr types.int;
        default = null;
      };

      multi-user = mkOption {
        type = types.bool;
        default = false;
      };

      cuda-device = mkOption {
        type = types.nullOr types.str;
        description = ''The CUDA device to use.  Query for this using lspci or lshw.  Leave as null to auto-detect and/or use Nix CUDA settings (verify this before merging!).'';
        default = null;
      };

      verbose = mkOption {
        type = types.bool;
        description = ''Use verbose logging.'';
        default = false;
      };

      cross-attention = mkOption {
        # TODO: Learn2enum in Nix.
        # Valid types should be "split", "quad", and "pytorch".
        type = types.nullOr types.enum;
        # TODO: Learn what cross-attention is, and describe it here.
        description = '' '';
        default = null;
      };

      preview-method = mkOption {
        type = types.nullOr types.oneOf [
          "none"
          "auto"
          "latent2rgb"
          "taesd"
        ];
        description = '' '';
        default = null;
      };

      # TODO: Provide these as formal arguments.
      # Argument dump:
      #  usage: comfyui [-h] [--listen [IP]] [--port PORT]
      #                 [--enable-cors-header [ORIGIN]]
      #                 [--max-upload-size MAX_UPLOAD_SIZE]
      #                 [--extra-model-paths-config PATH [PATH ...]]
      #                 [--output-directory OUTPUT_DIRECTORY]
      #                 [--temp-directory TEMP_DIRECTORY]
      #                 [--input-directory INPUT_DIRECTORY] [--auto-launch]
      #                 [--disable-auto-launch] [--cuda-device DEVICE_ID]
      #                 [--cuda-malloc | --disable-cuda-malloc]
      #                 [--dont-upcast-attention] [--force-fp32 | --force-fp16]
      #                 [--bf16-unet | --fp16-unet | --fp8_e4m3fn-unet | --fp8_e5m2-unet]
      #                 [--fp16-vae | --fp32-vae | --bf16-vae] [--cpu-vae]
      #                 [--fp8_e4m3fn-text-enc | --fp8_e5m2-text-enc | --fp16-text-enc | --fp32-text-enc]
      #                 [--directml [DIRECTML_DEVICE]] [--disable-ipex-optimize]
      #                 [--preview-method [none,auto,latent2rgb,taesd]]
      #                 [--use-split-cross-attention | --use-quad-cross-attention | --use-pytorch-cross-attention]
      #                 [--disable-xformers]
      #                 [--gpu-only | --highvram | --normalvram | --lowvram | --novram | --cpu]
      #                 [--disable-smart-memory] [--deterministic]
      #                 [--dont-print-server] [--quick-test-for-ci]
      #                 [--windows-standalone-build] [--disable-metadata]
      #                 [--multi-user] [--verbose]
      extraArgs = mkOption {
        type = types.attrsOf types.str;
        default = {};
        example = { fp16-vae = ""; };
        description = ''
          Additional arguments to be passed to comfyui
        '';
      };

      # TODO: Validate that the name of the package has extensions expected for
      # file depending on where it's going.  Without the extension, comfyui
      # won't find the file (or know how to treat the file), and a rename will
      # have to be done, potentially triggering a very expensive re-download.
      models = mkOption (let
        fetcher-type = (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
            };
            format = mkOption {
              type = types.str;
              default = "safetensors";
            };
            path = mkOption {
              # TODO: See if there is a path type we can use.
              type = types.str;
            };
          };
        });
        fetcher-option = mkOption {
          type = types.attrsOf fetcher-type;
          default = {};
        };
      in {
        type = (types.submodule {
          options = {
            checkpoints    = fetcher-option;
            clip           = fetcher-option;
            clip_vision    = fetcher-option;
            configs        = fetcher-option;
            controlnet     = fetcher-option;
            embeddings     = fetcher-option;
            loras          = fetcher-option;
            upscale_models = fetcher-option;
            vae            = fetcher-option;
            vae_approx     = fetcher-option;
          };
        });
        default = {
          checkpoints = {};
          clip = {};
          clip_vision = {};
          configs = {};
          controlnet = {};
          embeddings = {};
          loras = {};
          upscale_models = {};
          vae = {};
          vae_approx = {};
        };
      });
    };
  };

  config = mkIf cfg.enable {
    users.users = mkIf (cfg.user == defaultUser) {
      ${defaultUser} =
        { group = cfg.group;
          home  = cfg.dataPath;
          createHome = true;
          description = "ComfyUI daemon user";
          isSystemUser = true;
        };
    };

    users.groups = mkIf (cfg.group == defaultGroup) {
      ${defaultGroup} = {};
    };

    systemd.services.comfyui = let
      package = mkComfyUIPackage cfg;
    in {
      description = "ComfyUI Service";
      wantedBy = [ "multi-user.target" ];
      environment = {
        DATA = cfg.dataPath;
      };

      preStart = let
        inherit (lib.trivial) throwIfNot;
        inherit (lib) isAttr isString;
        inherit (lib.strings) concatStrings intersperse;
        inherit (lib.lists) flatten;
        inherit (lib.attrsets) attrValues mapAttrsToList;
        # And here is ++leftPad++ sorry `join`.
        join = (sep: (xs: concatStrings (intersperse sep xs)));
        join-lines = join "\n";
        # We don't have a type system and this is pretty deep in the call stack,
        # so do some checking on the inputs so we have fewer stones to overturn
        # when something goes wrong later.
        throw-if-not-fetched = fetched:
          throwIfNot (isAttrs fetched) "fetched must be an attrset."
          throwIfNot (isString fetched.format) "fetched.format must be a string."
          throwIfNot (isString fetched.path) "fetched.path must be a string."
        ;
        fetched-to-symlink = path: name: fetched: (
          throwIfNot (isString path) "path must be a string."
          throwIfNot (isString name) "name must be a string."
          throw-if-not-fetched fetched
            ''
             ln -snf ${fetched.path} $out/${name}.${fetched.format}
            ''
        );

        # TODO: Should we submit this as a core/built-in function?
        # TODO: I think linkFarm or linkFarmFromDrvs will work.  See
        # https://github.com/NixOS/nixpkgs/blob/b43d3db76831cb80db01dd2ed50d66175fa2a325/pkgs/build-support/trivial-builders.nix#L475
        # and
        # https://github.com/NixOS/nixpkgs/blob/b43d3db76831cb80db01dd2ed50d66175fa2a325/pkgs/build-support/trivial-builders.nix#L503
        # - commits not specific intentionally.
        # In its current state, it is not suitable for a general purpose tool.
        # Right now `paths` is expected to be symlink statements, with the name
        # done a particular way.  More thought should be given as to how that is
        # to be made generic, or the parameter must be renamed and documented.
        # Perhaps the consumer should make intermediate derivations that capture
        # the name in its pure form?
        # Like joinSymlinks, creates a derivation whose assets are joined.
        # joinSymlinks doesn't support joining a derivation that is the asset
        # itself.  This handles the single-asset case only.  See
        # https://discourse.nixos.org/t/how-to-create-package-with-multiple-sources/9308/3
        # for how to handle packages with multiple assets.
        join-single-assets-symlinks = { name, paths, ... }@args :
          pkgs.stdenv.mkDerivation ({
            inherit name;
            pname = name;
            sourceRoot = name; # Is this required?
            # When using srcs, Nix doesn't know what to do with the fetched
            # values, erroring out with "do not know how to unpack source
            # archive <path>".  Instead we use installPhase to symlink the
            # assets under $out.
            # srcs = ...;
            installPhase = ''
              mkdir -p $out
            '' + (join-lines paths);
            # No src/srcs, so don't do anything with them.
            phases = [ "installPhase" ];
          });

        # TODO: Make sure this comment still holds true.
        # Take all of the model files for the various model types defined in the
        # config of `models`, and translate it into a series of symlink shell
        # invocations.  The destination corresponds to the definitions in
        # `config-data`.
        # ex:
        #
        # linkModels
        #   {
        #     checkpoints = "/foo/checkpoints";
        #     vae = "/foo/vae";
        #   }
        #   {
        #     checkpoints = {
        #       sdxxl = fetchModel {
        #         url = "foo.com/sdxxl-v123";
        #         sha256 = "sha-string";
        #         format = "safetensors";
        #       };
        #     };
        #     vae = {
        #       fancy-vae = fetchModel {
        #         url = "foo.com/fancy-vae-v456";
        #         sha256 = "sha-string";
        #         # TODO: Use another format for example.
        #         format = "safetensors";
        #       };
        #     };
        #   }
        # Returns: ''
        # mkdir -p /foo/checkpoints
        # ln -s <sdxxl.drv> /foo/checkpoints/sdxxl.safetensors
        # mkdir -p /foo/vae
        # ln -s <fancy-vae.drv> /foo/vae/fancy-vae.safetensors
        # ''
        #
        linkModels = base-path: models:
          throwIfNot (isString base-path) "base-path must be a string."
            throwIfNot (isAttrs models) "models must be an attrset."
            (join-lines (builtins.map
              (x: ''
                  ln -snf ${x.drv} ${cfg.dataPath}/models/${x.model-type}
                '')
              (flatten
                (mapAttrsToList
                  (type: fetched-by-name: {
                    model-type = type;
                    # I cannot get linkFarm and linkFarmFromDrvs to work here. I
                    # get the error "error: value is a string with context while
                    # a set was expected".  This is in "dischargeProperties".  I
                    # cannot divine how that relates to my current calls and
                    # types, because we have no types and everything is lazily
                    # evaluated.  Perhaps a better Nix user than I can figure
                    # this out.
                    #
                    # That said, I get the same error when not using linkFarm.
                    # Changes are suspected to be related to work with getting
                    # the secrets to apply to fetchurl.
                    # drv = pkgs.linkFarm "comfyui-models-${type}" (
                    #   attrValues fetched-by-name
                    # );
                    drv = (join-single-assets-symlinks {
                      name = "comfyui-models-${type}";
                      paths = (mapAttrsToList
                        (fetched-to-symlink base-path)
                        fetched-by-name
                      );
                    });
                  })
                  models
                )
              )
            ))
        ;
      in ''
        mkdir -p ${cfg.dataPath}/input
        mkdir -p ${cfg.dataPath}/output
        ln -snf ${package}/custom_nodes ${cfg.dataPath}/custom_nodes
        ln -snf ${package}/extra_model_paths.yaml ${cfg.dataPath}/extra_model_paths.yaml
        mkdir -p ${cfg.dataPath}/models
        ${linkModels "${cfg.dataPath}/models" cfg.models}
      '';

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        # These directories must be relative to /var/lib.  Absolute paths are
        # greeted with:
        #  <path-to-unit>: StateDirectory= path is absolute, ignoring: <abs-path>
        RuntimeDirectory = [ service-name ];
        StateDirectory = [ service-name ];
        WorkingDirectory = "/run/${service-name}";
        ExecStart = let
          args = cli.toGNUCommandLine {} ({
            cpu = cfg.useCPU;
            enable-cors-header = cfg.cors-origin-domain;
            cuda-device = cfg.cuda-device;
            cuda-malloc = cfg.cuda-malloc;
            disable-cuda-malloc = !cfg.cuda-malloc;
            listen = cfg.listen;
            max-upload-size = cfg.max-upload-size;
            multi-user = cfg.multi-user;
            port = cfg.port;
            verbose = cfg.verbose;
            # TODO: Figure out how to enum into this.
            # Like this?
            # use-pytorch-cross-attention = cfg.cross-attention == "pytorch";
            # Or something dynamic + future proof?
          } // cfg.extraArgs);
        in ''${package}/bin/comfyui ${toString args}'';
        # TODO: Figure out what to do with dataPath, since it isn't used here
        # anymore.
        # StateDirectory = cfg.dataPath;
        # comfyui is prone to crashing on long slow workloads.
        Restart = "always";
        # Prevent it from restarting _too_ much though.  Stop if three times a
        # minute.  This might need a better default from someone with better
        # sysadmin chops.
        # TODO: One of these fields is invalid even though it's listed in the
        # documentation.  Need a link to the offending doc, the correct field to
        # use, and a pull request to correct it.
        StartLimitIntervalSec = "1m";
        StartLimitBurst = 3;
      };
    };
  };
}
