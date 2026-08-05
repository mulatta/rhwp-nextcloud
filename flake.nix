{
  description = "rhwp-nextcloud";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rhwp-nix.inputs.nixpkgs.follows = "nixpkgs";
    rhwp-nix.url = "github:mulatta/rhwp.nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
          rhwpPkgs = inputs.rhwp-nix.packages.${system};
          rhwp-viewer = pkgs.callPackage ./nix/rhwp-viewer.nix {
            inherit (rhwpPkgs) rhwp-studio rhwp-cli;
          };
        in
        {
          inherit rhwp-viewer;
          default = rhwp-viewer;
        }
      );

      checks = forAllSystems (
        system:
        nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          nextcloud = import ./nix/nixos-test.nix {
            inherit self;
            pkgs = pkgsFor.${system};
          };
        }
      );

      devShells = forAllSystems (system: {
        default = pkgsFor.${system}.mkShell { packages = [ ]; };
      });

      formatter = forAllSystems (
        system:
        (inputs.treefmt-nix.lib.evalModule pkgsFor.${system} {
          projectRootFile = "flake.nix";
          programs = {
            deadnix.enable = true;
            nixfmt.enable = true;
            php-cs-fixer.enable = true;
            prettier.enable = true;
            statix.enable = true;
            xmllint.enable = true;
          };
        }).config.build.wrapper
      );

      nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [ ./nix/test-vm.nix ];
      };
    };
}
