{
  description = "rhwp-nextcloud";

  inputs = {
    # keep-sorted start
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rhwp-nix.inputs.nixpkgs.follows = "nixpkgs";
    rhwp-nix.url = "github:mulatta/rhwp-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    # keep-sorted end
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [ inputs.treefmt-nix.flakeModule ];

      flake.nixosConfigurations.test = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [ ./nix/test-vm.nix ];
      };

      perSystem =
        { pkgs, system, ... }:
        let
          rhwpPkgs = inputs.rhwp-nix.packages.${system};
          rhwp-viewer = pkgs.callPackage ./nix/rhwp-viewer.nix {
            inherit (rhwpPkgs) rhwp-studio rhwp-cli;
          };
        in
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          packages = {
            inherit rhwp-viewer;
            default = rhwp-viewer;
          };

          devShells.default = pkgs.mkShell { packages = [ ]; };

          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              # keep-sorted start
              deadnix.enable = true;
              keep-sorted.enable = true;
              nixfmt.enable = true;
              statix.enable = true;
              # keep-sorted end
            };
          };
        };
    };
}
