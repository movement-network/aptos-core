{
  description = "Aptos Core - Layer 1 blockchain";

  nixConfig = {
    extra-substituters = [
      "https://movementlabsxyz.cachix.org"
    ];
    extra-trusted-public-keys = [
      "movementlabsxyz.cachix.org-1:ap2x2pbuuPk8hJr3B7jkXiP32UvJWpcmQ38RVB4P0cU="
    ];
  };

  inputs = {
    # Pin to same nixpkgs as movement repo for compatibility
    nixpkgs.url = "github:NixOS/nixpkgs/a7abebc31a8f60011277437e000eebcc01702b9f";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crane.url = "github:ipetkov/crane";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-linux" ] (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        lib = pkgs.lib;
        stdenv = pkgs.stdenv;

        # Rust toolchain from rust-toolchain.toml
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ../rust-toolchain.toml;

        # Create craneLib with our toolchain
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        # Darwin frameworks for macOS
        frameworks = pkgs.darwin.apple_sdk.frameworks;

        # Source filtering - only include Rust-relevant files
        src = lib.cleanSourceWith {
          src = ./..;
          filter = path: type:
            (craneLib.filterCargoSources path type)
            || (builtins.match ".*\\.proto$" path != null)
            || (builtins.match ".*\\.toml$" path != null)
            || (builtins.match ".*aptos-move/.*" path != null)
            || (builtins.match ".*movement-migration/.*" path != null);
        };

        # Platform-specific RUSTFLAGS
        # SSE4.2 is only available on x86_64
        platformRustFlags = lib.optionalString (system == "x86_64-linux") "-C target-feature=+sse4.2";

        # Common build inputs for all packages (platform-aware)
        commonBuildInputs = with pkgs; [
          openssl
          rocksdb
          zlib
          jemalloc
          protobuf
        ] ++ lib.optionals stdenv.isDarwin [
          frameworks.Security
          frameworks.CoreServices
          frameworks.SystemConfiguration
          frameworks.AppKit
          libiconv
          libelf
        ] ++ lib.optionals stdenv.isLinux [
          elfutils
          udev
          systemd
        ];

        # Common native build inputs
        commonNativeBuildInputs = with pkgs; [
          pkg-config
          cmake
          clang
          llvm
          lld
          protobuf
          rustPlatform.bindgenHook
        ];

        # Library path for linking (platform-aware)
        libraryPath = lib.makeLibraryPath ([
          pkgs.openssl
          pkgs.rocksdb
          pkgs.zlib
          pkgs.jemalloc
          pkgs.stdenv.cc.cc.lib
        ] ++ lib.optionals stdenv.isLinux [
          pkgs.elfutils
        ]);

        # Common arguments for all crane builds
        commonArgs = {
          inherit src;
          strictDeps = true;

          buildInputs = commonBuildInputs;
          nativeBuildInputs = commonNativeBuildInputs;

          # Environment variables
          LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";
          JEMALLOC_OVERRIDE = if stdenv.isLinux then "${pkgs.jemalloc}/lib/libjemalloc.so" else "${pkgs.jemalloc}/lib/libjemalloc.dylib";
          CARGO_BUILD_RUSTFLAGS = "${platformRustFlags} -C opt-level=3";
          # Disable jemalloc-sys from building from source
          JEMALLOC_SYS_WITH_MALLOC_CONF = "";

          # Additional library paths for linking
          LD_LIBRARY_PATH = libraryPath;
        };

        # Build dependencies only (for caching)
        cargoArtifacts = craneLib.buildDepsOnly (commonArgs // {
          pname = "aptos-deps";
          version = "0.1.0";
          # Use all workspace crates for deps caching
          cargoExtraArgs = "--workspace";
        });

        # Helper function to build a specific binary
        mkPackage = { pname, cargoPackage ? pname, binary ? pname }: craneLib.buildPackage (commonArgs // {
          inherit pname cargoArtifacts;
          version = "0.1.0";
          cargoExtraArgs = "-p ${cargoPackage}";
          # Only install the specific binary
          postInstall = ''
            # Ensure only the target binary is in bin/
            if [ -f "$out/bin/${binary}" ]; then
              echo "Binary ${binary} built successfully"
            else
              echo "Warning: Expected binary ${binary} not found"
              ls -la "$out/bin/" || true
            fi
          '';
        });

        # Individual package definitions
        aptos-node = mkPackage {
          pname = "aptos-node";
          cargoPackage = "aptos-node";
          binary = "aptos-node";
        };

        # movement binary comes from the 'aptos' cargo package
        movement = mkPackage {
          pname = "movement";
          cargoPackage = "aptos";
          binary = "movement";
        };

        l1-migration = mkPackage {
          pname = "l1-migration";
          cargoPackage = "l1-migration";
          binary = "l1-migration";
        };

        aptos-faucet-service = mkPackage {
          pname = "aptos-faucet-service";
          cargoPackage = "aptos-faucet-service";
          binary = "aptos-faucet-service";
        };

        aptos-transaction-emitter = mkPackage {
          pname = "aptos-transaction-emitter";
          cargoPackage = "aptos-transaction-emitter";
          binary = "aptos-transaction-emitter";
        };

        # All binaries combined
        all-binaries = pkgs.symlinkJoin {
          name = "aptos-all-binaries";
          paths = [
            aptos-node
            movement
            l1-migration
            aptos-faucet-service
            aptos-transaction-emitter
          ];
        };

        # Container runtime dependencies (Linux only - containers run on Linux)
        containerRuntimeDeps = with pkgs; [
          jemalloc
          elfutils
          rocksdb
          openssl
          zlib
          cacert
          # For shell access in container debugging
          bashInteractive
          coreutils
        ];

        # Container for aptos-node (includes aptos-node, movement, l1-migration)
        # Only available on Linux
        container-aptos-node = if stdenv.isLinux then pkgs.dockerTools.buildImage {
          name = "ghcr.io/movementlabsxyz/aptos-node";
          tag = "nix";

          copyToRoot = pkgs.buildEnv {
            name = "aptos-node-root";
            paths = [
              aptos-node
              movement
              l1-migration
            ] ++ containerRuntimeDeps;
            pathsToLink = [ "/bin" "/lib" "/etc" ];
          };

          config = {
            Env = [
              "LD_LIBRARY_PATH=/lib"
              "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
            ];
            Entrypoint = [ "/bin/aptos-node" ];
            Cmd = [ "--version" ];
            WorkingDir = "/app";
          };

          # Create backwards compatibility symlink: aptos -> movement
          extraCommands = ''
            mkdir -p app
            ln -sf /bin/movement bin/aptos || true
          '';
        } else null;

        # Container for aptos-faucet-service (Linux only)
        container-aptos-faucet-service = if stdenv.isLinux then pkgs.dockerTools.buildImage {
          name = "ghcr.io/movementlabsxyz/aptos-faucet-service";
          tag = "nix";

          copyToRoot = pkgs.buildEnv {
            name = "aptos-faucet-service-root";
            paths = [
              aptos-faucet-service
            ] ++ containerRuntimeDeps;
            pathsToLink = [ "/bin" "/lib" "/etc" ];
          };

          config = {
            Env = [
              "LD_LIBRARY_PATH=/lib"
              "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
            ];
            Entrypoint = [ "/bin/aptos-faucet-service" ];
            Cmd = [ "-h" ];
            WorkingDir = "/app";
          };

          extraCommands = ''
            mkdir -p app
          '';
        } else null;

      in
      {
        packages = {
          inherit aptos-node movement l1-migration aptos-faucet-service aptos-transaction-emitter;
          inherit all-binaries;
          default = all-binaries;
        } // lib.optionalAttrs stdenv.isLinux {
          inherit container-aptos-node container-aptos-faucet-service;
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

              # Development tools
              git
              curl
              jq
              nodejs
            ] ++ lib.optionals stdenv.isDarwin [
              frameworks.Security
              frameworks.CoreServices
              frameworks.SystemConfiguration
              frameworks.AppKit
              libiconv
              libelf
            ] ++ lib.optionals stdenv.isLinux [
              elfutils
              elfutils.dev
              elfutils.out
              udev
            ];

            # Environment variables for library paths
            LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
            BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.libclang.dev}/include";

            # Add PKG_CONFIG_PATH to help find libraries
            PKG_CONFIG_PATH = lib.makeSearchPath "lib/pkgconfig" ([
              pkgs.zlib
            ] ++ lib.optionals stdenv.isLinux [
              pkgs.elfutils.dev
            ]);

            # Additional library paths
            LD_LIBRARY_PATH = lib.makeLibraryPath ([
              pkgs.libclang.lib
              pkgs.llvm.lib
              pkgs.zlib
              pkgs.jemalloc
              pkgs.rocksdb
              pkgs.stdenv.cc.cc.lib
              pkgs.openssl.out
            ] ++ lib.optionals stdenv.isLinux [
              pkgs.elfutils
              pkgs.elfutils.out
            ]);

            # Environment variables for build configuration
            CARGO_BUILD_RUSTFLAGS = "${platformRustFlags} -C opt-level=3";
            RUST_BACKTRACE = "1";
            ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";

            # Fix jemalloc-sys build issues with strerror_r
            JEMALLOC_SYS_WITH_MALLOC_CONF = "";
            # Override jemalloc-sys to use system jemalloc instead of building from source
            JEMALLOC_OVERRIDE = if stdenv.isLinux then "${pkgs.jemalloc}/lib/libjemalloc.so" else "${pkgs.jemalloc}/lib/libjemalloc.dylib";

            # Shell hooks to ensure correct toolchain is used
            shellHook = ''
              echo "Welcome to the Aptos Node development environment"
              echo "Run 'cargo build' to build the project"
              echo ""
              echo "Nix build commands available:"
              echo "  nix build .#aptos-node              - Build aptos-node binary"
              echo "  nix build .#movement                - Build movement CLI binary"
              echo "  nix build .#l1-migration            - Build l1-migration tool"
              echo "  nix build .#aptos-faucet-service    - Build faucet service"
              echo "  nix build .#aptos-transaction-emitter - Build transaction emitter"
              echo "  nix build .#all-binaries            - Build all binaries"
              ${lib.optionalString stdenv.isLinux ''echo "  nix build .#container-aptos-node    - Build aptos-node container"''}
              echo ""

              # Ensure Nix-provided Clang and LLVM are used
              export PATH="${pkgs.clang}/bin:${pkgs.llvm}/bin:$PATH"
            '';
          };
        };

        # Apps for running binaries directly with 'nix run'
        apps = {
          aptos-node = {
            type = "app";
            program = "${aptos-node}/bin/aptos-node";
          };
          movement = {
            type = "app";
            program = "${movement}/bin/movement";
          };
          l1-migration = {
            type = "app";
            program = "${l1-migration}/bin/l1-migration";
          };
          aptos-faucet-service = {
            type = "app";
            program = "${aptos-faucet-service}/bin/aptos-faucet-service";
          };
          aptos-transaction-emitter = {
            type = "app";
            program = "${aptos-transaction-emitter}/bin/aptos-transaction-emitter";
          };
          default = {
            type = "app";
            program = "${aptos-node}/bin/aptos-node";
          };
        };
      });
}
