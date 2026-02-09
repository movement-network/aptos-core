{
  description = "Aptos Core - Layer 1 blockchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crane.url = "github:ipetkov/crane";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ../rust-toolchain.toml;

        # Use crane with our custom rust toolchain for building packages
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        # Use the full source tree (includes .proto, .mv, .mrb, .yaml, etc.)
        src = ./..;

        # Some git dependencies are pinned to commits no longer reachable from
        # their recorded branch ref. Vendor by locked rev across all refs.
        overrideVendorGitCheckoutAllRefs = ps: _drv:
          let
            p = builtins.head ps;
            sourceWithoutPrefix = pkgs.lib.removePrefix "git+" p.source;
            sourceSplit = builtins.split "#" sourceWithoutPrefix;
            sourceBeforeRev = builtins.head sourceSplit;
            lockedRev =
              if 3 == builtins.length sourceSplit then
                builtins.elemAt sourceSplit 2
              else
                throw "Malformed Cargo.lock git source for ${p.name}: ${p.source}";
            gitUrl = builtins.head (builtins.split "\\?" sourceBeforeRev);
          in
          craneLib.downloadCargoPackageFromGit {
            git = gitUrl;
            rev = lockedRev;
            allRefs = true;
            ref = null;
          };

        cargoVendorDir = craneLib.vendorCargoDeps {
          inherit src;
          cargoLock = ../Cargo.lock;
          overrideVendorGitCheckout = overrideVendorGitCheckoutAllRefs;
        };

        # Common args shared between buildDepsOnly and buildPackage
        commonArgs = {
          inherit src cargoVendorDir;
          strictDeps = true;

          nativeBuildInputs = with pkgs; [
            pkg-config
            cmake
            clang
            protobuf
            llvm
            lld
          ];

          buildInputs = with pkgs; [
            openssl
            rocksdb
            libclang
            zlib
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.elfutils
            pkgs.udev
          ];

          LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.libclang.dev}/include";
          ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";
          # Let jemalloc-sys build from source with correct _rjem_ prefix
          # (system jemalloc lacks the prefix, causing linker errors)
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
            libclang.lib llvm.lib zlib rocksdb stdenv.cc.cc.lib openssl.out
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            elfutils
          ]);

          doCheck = false;
        };

        # Build workspace dependencies (cached separately from source changes)
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        # Common args for individual crate builds
        crateArgs = commonArgs // {
          inherit cargoArtifacts;
        };

      in
      {
        packages = {
          aptos-node = craneLib.buildPackage (crateArgs // {
            pname = "aptos-node";
            version = "0.1.0";
            cargoExtraArgs = "-p aptos-node";
          });

          movement = craneLib.buildPackage (crateArgs // {
            pname = "movement";
            version = "0.1.0";
            cargoExtraArgs = "-p movement";
          });

          l1-migration = craneLib.buildPackage (crateArgs // {
            pname = "l1-migration";
            version = "0.1.0";
            cargoExtraArgs = "-p l1-migration";
          });

          aptos-faucet-service = craneLib.buildPackage (crateArgs // {
            pname = "aptos-faucet-service";
            version = "0.1.0";
            cargoExtraArgs = "-p aptos-faucet-service";
          });

          aptos-transaction-emitter = craneLib.buildPackage (crateArgs // {
            pname = "aptos-transaction-emitter";
            version = "0.1.0";
            cargoExtraArgs = "-p aptos-transaction-emitter";
          });

          all-binaries = pkgs.symlinkJoin {
            name = "aptos-all-binaries";
            paths = [
              self.packages.${system}.aptos-node
              self.packages.${system}.movement
              self.packages.${system}.l1-migration
              self.packages.${system}.aptos-faucet-service
              self.packages.${system}.aptos-transaction-emitter
            ];
          };
        };

        devShells = {
          default = pkgs.mkShell {
            name = "aptos-node-dev";

            buildInputs = with pkgs; [
              rustToolchain
              rustfmt
              clippy
              rust-analyzer

              # System dependencies
              openssl
              pkg-config
              cmake
              clang
              rocksdb
              protobuf
              libclang
              llvm
              lld
              zlib
              jemalloc
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              pkgs.elfutils
              pkgs.elfutils.dev
              pkgs.elfutils.out
              pkgs.udev
            ] ++ [
              # Development tools
              git
              curl
              jq
              nodejs
            ];

            # Environment variables for library paths
            LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
            BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.libclang.dev}/include";

            # Add PKG_CONFIG_PATH to help find libraries
            PKG_CONFIG_PATH = "${pkgs.zlib}/lib/pkgconfig:$PKG_CONFIG_PATH"
              + pkgs.lib.optionalString pkgs.stdenv.isLinux ":${pkgs.elfutils.dev}/lib/pkgconfig";

            # Additional library paths
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath ([
              pkgs.libclang.lib pkgs.llvm.lib pkgs.zlib pkgs.jemalloc pkgs.rocksdb pkgs.stdenv.cc.cc.lib pkgs.openssl.out
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              pkgs.elfutils pkgs.elfutils.out
            ]);

            # Environment variables for build configuration
            CARGO_BUILD_RUSTFLAGS = "-C target-feature=+sse4.2 -C opt-level=3";
            RUST_BACKTRACE = 1;
            ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";

            # Fix jemalloc-sys build issues with strerror_r
            JEMALLOC_SYS_WITH_MALLOC_CONF = "";
            # Override jemalloc-sys to use system jemalloc instead of building from source
            JEMALLOC_OVERRIDE = "${pkgs.jemalloc}/lib/libjemalloc${if pkgs.stdenv.isDarwin then ".dylib" else ".so"}";

            # Shell hooks to ensure correct toolchain is used
            shellHook = ''
              echo "Welcome to the Aptos Node development environment"
              echo "Run 'cargo build' to build the project"

              # Ensure Nix-provided Clang and LLVM are used
              export PATH="${pkgs.clang}/bin:${pkgs.llvm}/bin:$PATH"
            '';
          };
        };

        apps = {
          aptos-node = {
            type = "app";
            program = "${self.packages.${system}.aptos-node}/bin/aptos-node";
          };
        };
      });
}
