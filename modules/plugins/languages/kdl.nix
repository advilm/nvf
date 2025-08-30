{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (builtins) attrNames;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.types) enum either package listOf str;
  inherit (lib.meta) getExe;
  inherit (lib.nvim.types) mkGrammarOption;

  cfg = config.vim.languages.kdl;

  defaultServer = "kdl-lsp";
  servers = {
    "kdl-lsp" = {
      package = pkgs.rustPlatform.buildRustPackage rec {
        pname = "kdl-lsp";
        version = "6.3.3";
        src = pkgs.fetchCrate {
          inherit pname version;
          hash = "sha256-e1JBdEDU77WAILp59QD1UQEcpkZmdE3Um/Ya8CZPynQ=";
        };
        cargoHash = "sha256-kHAUnIxlCfN+XsIFery7VIjZcuHWyoZI38UV2+w0Aos=";
      };
      lspConfig = ''
        configs.kdl_lsp = {
          default_config = {
            cmd = {"${cfg.lsp.package}/bin/kdl-lsp"},
            root_dir = lspconfig.util.root_pattern('.git'),
            filetypes = { 'kdl' },
          },
        }
        lspconfig.kdl_lsp.setup {
          capabilities = capabilities,
          on_attach = default_on_attach,
        }
      '';
    };
  };

  defaultFormat = "kdlfmt";
  formats = {
    kdlfmt = {
      package = pkgs.kdlfmt;
    };
  };
in {
  options.vim.languages.kdl = {
    enable =
      mkEnableOption "Enable KDL language support" // {default = false;};
    treesitter = {
      enable =
        mkEnableOption "KDL treesitter support" // {default = config.vim.languages.enableTreesitter;};
      package = mkGrammarOption pkgs "kdl";
    };
    lsp = {
      enable =
        mkEnableOption "KDL LSP support" // { default = config.vim.lsp.enable; };

      server = mkOption {
        description = "KDL LSP server to use";
        type = enum (attrNames servers);
        default = defaultServer;
      };

      package = mkOption {
        description = "KDL LSP package, or the command to run as a list of strings";
        type = either package (listOf str);
        default = servers.${defaultServer}.package;
      };
    };
    format = {
      enable = mkEnableOption "KDL document formatting" // {default = config.vim.languages.enableFormat;};

      type = mkOption {
        description = "KDL formatter to use";
        type = enum (attrNames formats);
        default = defaultFormat;
      };

      package = mkOption {
        description = "KDL formatter package";
        type = package;
        default = formats.${cfg.format.type}.package;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.treesitter.enable {
      vim = {
        treesitter = {
          enable = true;
          grammars = [cfg.treesitter.package];
        };
      };
    })

    (mkIf cfg.lsp.enable {
      vim.lsp.lspconfig.enable = true;
      vim.lsp.lspconfig.sources.kdl-lsp = servers.${cfg.lsp.server}.lspConfig;
    })

    (mkIf cfg.format.enable {
      vim.formatter.conform-nvim = {
        enable = true;
        setupOpts.formatters_by_ft.kdl = [cfg.format.type];
        setupOpts.formatters.${cfg.format.type} = {
          command = getExe cfg.format.package;
        };
      };
    })
  ]);
}
