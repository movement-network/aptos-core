{
  description = "Aptos Core - Layer 1 blockchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ../rust-toolchain.toml;

        # Create a custom rustPlatform with the specified toolchain
        customRustPlatform = pkgs.makeRustPlatform {
          rustc = rustToolchain;
          cargo = rustToolchain;
        };

        # Common args for all binary packages
        commonBuildArgs = {
          version = "0.1.0";
          src = ./..;
          cargoLock = {
            lockFile = ../Cargo.lock;
            outputHashes = {
              "aptos-indexer-processor-sdk-0.1.0" = "11rwy4zy46y28r6q1cpzswyjm5sg6anf114ak1a8ckscjqqv8av5";
              "aptos-indexer-transaction-stream-0.1.0" = "11rwy4zy46y28r6q1cpzswyjm5sg6anf114ak1a8ckscjqqv8av5";
              "aptos-moving-average-0.1.0" = "1bwprk7w7p9q46am45gal4jsx2nz90maasdd8m818vd8yl1x4nal";
              "aptos-profiler-0.1.0" = "1q6wf7vfny14lvwm416j2996dq9d46c8vn88g21m5abxw5qkx3hd";
              "aptos-protos-1.3.1" = "1q6wf7vfny14lvwm416j2996dq9d46c8vn88g21m5abxw5qkx3hd";
              "aptos-system-utils-0.1.0" = "1q6wf7vfny14lvwm416j2996dq9d46c8vn88g21m5abxw5qkx3hd";
              "aptos-transaction-filter-0.1.0" = "1q6wf7vfny14lvwm416j2996dq9d46c8vn88g21m5abxw5qkx3hd";
              "bcs-0.1.4" = "1n0syyqxz6k3g02wriggmm111z1pqpzd67irqv21ahfj68286csb";
              "diesel-async-0.5.2" = "0x1rzrqmlxfz1l5iikg8sapbnvvkxqg1ibpzdd9gjy656zpgr4cf";
              "firebase-token-0.3.0" = "1xb7jhvmxpnwb3ys5wfbg21m9krxrzbm937k376xq8ay7l3rhfkc";
              "futures-0.3.30" = "10m8k8s64m693n801gj0ygd8p5h89y1a7x5lkyh8w5316d7wcfcd";
              "futures-channel-0.3.30" = "10m8k8s64m693n801gj0ygd8p5h89y1a7x5lkyh8w5316d7wcfcd";
              "futures-core-0.3.30" = "10m8k8s64m693n801gj0ygd8p5h89y1a7x5lkyh8w5316d7wcfcd";
              "futures-executor-0.3.30" = "10m8k8s64m693n801gj0ygd8p5h89y1a7x5lkyh8w5316d7wcfcd";
              "futures-io-0.3.30" = "10m8k8s64m693n801gj0ygd8p5h89y1a7x5lkyh8w5316d7wcfcd";
              "futures-macro-0.3.30" = "10m8k8s64m693n801gj0ygd8p5h89y1a7x5lkyh8w5316d7wcfcd";
              "futures-sink-0.3.30" = "10m8k8s64m693n801gj0ygd8p5h89y1a7x5lkyh8w5316d7wcfcd";
              "futures-task-0.3.30" = "10m8k8s64m693n801gj0ygd8p5h89y1a7x5lkyh8w5316d7wcfcd";
              "futures-util-0.3.30" = "10m8k8s64m693n801gj0ygd8p5h89y1a7x5lkyh8w5316d7wcfcd";
              "instrumented-channel-0.1.0" = "11rwy4zy46y28r6q1cpzswyjm5sg6anf114ak1a8ckscjqqv8av5";
              "merlin-3.0.0" = "0ljb9gdxkh76iss6mnx12aj3b4qiskf192f1h7vhs45mljcxy114";
              "poseidon-ark-0.0.1" = "0q6zzyx3mhr6lb6mifc2i7z5ni3gwv3wki3pdzmyqf5z439dydy4";
              "processor-0.1.0" = "1di9iig9hyihsf12v29wfln1rccaj7vivjcmm80zpr4idwzi2j7i";
              "sample-0.1.0" = "11rwy4zy46y28r6q1cpzswyjm5sg6anf114ak1a8ckscjqqv8av5";
              "self_update-0.39.0" = "1z88scq08ap9zhfbndrfjjw9mwcifca61gvn4wz57b972lb58xn1";
              "serde-generate-0.20.6" = "04xnizqnlsvy3af83iy0p5l3prybj47s546497shngck52gn5brr";
              "serde-reflection-0.3.5" = "04xnizqnlsvy3af83iy0p5l3prybj47s546497shngck52gn5brr";
              "x25519-dalek-1.2.0" = "06qqrzf4k8qzpsq5n7ipxjv0himafrjyiw3dnq1m1xk3n0nsi5k8";
            };
          };

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
            jemalloc
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.elfutils
            pkgs.udev
          ];

          LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.libclang.dev}/include";
          ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";
          JEMALLOC_OVERRIDE = "${pkgs.jemalloc}/lib/libjemalloc${if pkgs.stdenv.isDarwin then ".dylib" else ".so"}";
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
            libclang.lib llvm.lib zlib jemalloc rocksdb stdenv.cc.cc.lib openssl.out
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            elfutils
          ]);

          doCheck = false;
        };

      in
      {
        packages = {
          aptos-node = customRustPlatform.buildRustPackage (commonBuildArgs // {
            pname = "aptos-node";
            cargoBuildFlags = ["-p" "aptos-node"];
          });

          movement = customRustPlatform.buildRustPackage (commonBuildArgs // {
            pname = "movement";
            cargoBuildFlags = ["-p" "movement"];
          });

          l1-migration = customRustPlatform.buildRustPackage (commonBuildArgs // {
            pname = "l1-migration";
            cargoBuildFlags = ["-p" "l1-migration"];
          });

          all-binaries = pkgs.symlinkJoin {
            name = "aptos-all-binaries";
            paths = [
              self.packages.${system}.aptos-node
              self.packages.${system}.movement
              self.packages.${system}.l1-migration
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
