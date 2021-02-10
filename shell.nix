with import <nixpkgs> {};

mkShell {
  buildInputs = [
    stdenv

    gnumake
    pkgconfig
    wget
    unzip
    jq
    mtools
    gzip
    cpio
    squashfsTools
    qemu #qemu_full
    cdrkit  # for genisoimage
    advancecomp

    python3Packages.fastapi
    python3Packages.uvicorn
  ];
}
