{ rustPlatform, lib }:

rustPlatform.buildRustPackage {
  pname = "otpdash";
  version = "unstable";
  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;
}
