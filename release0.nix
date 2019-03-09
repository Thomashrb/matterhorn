let
 ghc-options = [
    # Enable threading.
    "-threaded" "-rtsopts" "-with-rtsopts=-N"
  ];

  config = {
    packageOverrides = pkgs: rec {
      haskellPackages = pkgs.haskellPackages.override {
        overrides = haskellPackagesNew: haskellPackagesOld: rec {
          matterhorn =
            haskellPackagesNew.callPackage ./default.nix { };

          brick =
            haskellPackagesNew.callPackage ./pkgversion/brick.nix { };

          vty =
            haskellPackagesNew.callPackage ./pkgversion/vty.nix { };

          mattermost-api =
            haskellPackagesNew.callPackage ./pkgversion/mattermost-api.nix { };

          mattermost-api-qc =
            haskellPackagesNew.callPackage ./pkgversion/mattermost-api-qc.nix { };

        };
      };
    };
  };

  pkgs = import <nixpkgs> { inherit config; };

in
  { matterhorn = pkgs.haskellPackages.matterhorn;
  }
