{
  description = "Jenkins Kubernetes Operator";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    go_15.url = "github:nixos/nixpkgs/4eccd6f731627ba5ad9915bcf600c9329a34ca78";
    golangci.url = "github:nixos/nixpkgs/e912fb83d2155a393e7146da98cda0e455a80fb6";
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, go_15, golangci, gomod2nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        go_15_pkgs = go_15.legacyPackages.${system};
        golangci_pkgs = golangci.legacyPackages.${system};
        operatorVersion = builtins.readFile ./VERSION.txt;
        sdkVersion = ((builtins.fromTOML (builtins.readFile ./config.base.env)).OPERATOR_SDK_VERSION);
        jenkinsLtsVersion = ((builtins.fromTOML (builtins.readFile ./config.base.env)).LATEST_LTS_VERSION);
      in
      {
        # Nix fmt
        formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;

        # shell in nix develop
        devShells.default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [
              pkgs.gnumake
              pkgs.wget
              pkgs.helm-docs
              (pkgs.writeShellApplication {
                name = "make_matrix";
                runtimeInputs = with pkgs; [ bash gnugrep gawk ];
                text = builtins.readFile ./test/make_matrix_ginkgo.sh;
              })
              go_15_pkgs.go
              golangci_pkgs.golangci-lint
          ];
          shellHook = ''
              echo Operator Version ${operatorVersion}
              echo Latest Jenkins LTS version: ${jenkinsLtsVersion}
              echo Operator SDK version: ${sdkVersion}
          '';
        };

        # nix shell .#gomod
        devShells.gomod = pkgs.callPackage ./nix/shell.nix {
            inherit (gomod2nix.legacyPackages.${system}) mkGoEnv gomod2nix;
        };

        # nix build with gomod2nix
        packages.default = pkgs.callPackage ./nix {
            inherit (gomod2nix.legacyPackages.${system}) buildGoApplication;
        };

      }
    );
}
