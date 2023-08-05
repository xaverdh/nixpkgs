{ lib, stdenv, fetchFromGitHub
, opencv, dlib, gmock, gtest
, python3, unzip
, libpng, libjpeg
, cmake, boost, ninja, clang
, makeWrapper }:

let
  python = python3;
  #opencv-tbb = opencv.override { enableTbb = true; };
in stdenv.mkDerivation {
  pname = "photo-id-creator";
  version = "unstable-2019-12-08";

  src = fetchFromGitHub {
    owner = "dpar39";
    repo = "ppp";
    rev = "1bdd1b59a4a6104a9cca3107d0b2c3e459f7389b";
    hash = "sha256-QZc2Hr+oTKtfCRBuE5KfI30Sl3nHXozJCZi9MmV+eNE=";
  };

  patches = [ ./cmake-list.patch ./build-py.patch ];

  nativeBuildInputs = [
    python unzip
    cmake ninja clang
    makeWrapper
  ];

  buildInputs = [
    gmock gtest
    opencv dlib boost
    libpng libjpeg
  ];

  postPatch = ''
    sed -i 's|self.build_dlib()|pass|g' build.py
    sed -i 's|self.build_googletest()|pass|g' build.py
    sed -i 's|self.build_opencv()|pass|g' build.py
    rm -Rf thirdparty/tools/
  '';
  buildPhase = ''
    runHook preBuild
    python ../build.py -a x64 --test
    runHook postBuild
  '';
  installPhase = ''
    mkdir -p $out

    cp -R -t $out $NIX_BUILD_TOP/source/install_linux_release_x64/*
    install -t $out $NIX_BUILD_TOP/source/libppp/share/config.bundle.json

    makeWrapper $out/bin/ppp_app $out/bin/photo-id-creator \
      --add-flags "--config $out/share/config.bundle.json"
  '';
  meta = with lib; {
    mainProgram = "photo-id-creator";
    description = "Prepare photo IDs (Cli part)";
    homepage = "https://github.com/dpar39/ppp";
    #license = with licenses; [ TODO ];
    maintainers = with maintainers; [ xaverdh ];
    platforms = platforms.linux;
  };
}
