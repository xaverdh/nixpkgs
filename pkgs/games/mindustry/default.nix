{ lib, stdenv
, makeWrapper
, makeDesktopItem
, copyDesktopItems
, fetchFromGitHub
, fetchpatch
, gradleGen
, jdk
, perl

# for arc
, SDL2
, pkg-config
, stb
, ant
, alsaLib
, glew

# Make the build version easily overridable.
# Server and client build versions must match, and an empty build version means
# any build is allowed, so this parameter acts as a simple whitelist.
# Takes the package version and returns the build version.
, makeBuildVersion ? (v: v)
, enableClient ? true
, enableServer ? true
}:

let
  pname = "mindustry";
  # Note: when raising the version, ensure that all SNAPSHOT versions in
  # build.gradle are replaced by a fixed version
  # (the current one at the time of release) (see postPatch).
  version = "122.1";
  buildVersion = makeBuildVersion version;

  Mindustry = fetchFromGitHub {
    owner = "Anuken";
    repo = "Mindustry";
    rev = "v${version}";
    sha256 = "18m4s81cfb2cr2fj61nf6spiln7cbvx25g42w6fypfikflv3qd8y";
  };
  Arc = fetchFromGitHub {
    owner = "Anuken";
    repo = "Arc";
    rev = "v${version}";
    sha256 = "0inzyj01442da7794cpxlaab7di9gv1snc97cbffqsdxgin16i7d";
  };
  soloud = fetchFromGitHub {
    owner = "Anuken";
    repo = "soloud";
    # this is never pinned in upstream, see https://github.com/Anuken/Arc/issues/39
    rev = "8553049c6fb0d1eaa7f57c1793b96219c84e8ba5";
    sha256 = "076vnjs2qxd65qq5i37gbmj5v5i04a1vw0kznq986gv9190jj531";
  };

  patches = [
    ./0001-fix-include-path-for-SDL2-on-linux.patch
    # upstream fix for https://github.com/Anuken/Arc/issues/40, remove on next release
    (fetchpatch {
      url = "https://github.com/Anuken/Arc/commit/b2f3d212c1a88a62f140f5cb04f4c86e61332d1c.patch";
      sha256 = "1yjp4drv7lk3kinzy47g8jhb2qazr92b85vbc79vsqrs8sycskan";
      extraPrefix = "Arc/";
      stripLen = 1;
    })
    # add resolveDependencies task, remove when and if it gets added upstream in a future release
    (fetchpatch {
      url = "https://github.com/Anuken/Mindustry/pull/4302.patch";
      sha256 = "0yp42sray4fxkajhpdljal0wss8jh9rvmclysw6cixsa94pw5khq";
      extraPrefix = "Mindustry/";
      stripLen = 1;
    })
  ];

  unpackPhase = ''
    cp -r ${Mindustry} Mindustry
    cp -r ${Arc} Arc
    chmod -R u+w -- Mindustry Arc
    cp ${stb.src}/stb_image.h Arc/arc-core/csrc/
    cp -r ${soloud} Arc/arc-core/csrc/soloud
    chmod -R u+w -- Arc
  '';

  desktopItem = makeDesktopItem {
    type = "Application";
    name = "Mindustry";
    desktopName = "Mindustry";
    exec = "mindustry";
    icon = "mindustry";
  };

  cleanupMindustrySrc = ''
    pushd Mindustry

    # Remove unbuildable iOS stuff
    sed -i '/^project(":ios"){/,/^}/d' build.gradle
    sed -i '/robo(vm|VM)/d' build.gradle
    rm ios/build.gradle

    # Pin 'SNAPSHOT' versions
    sed -i 's/com.github.anuken:packr:-SNAPSHOT/com.github.anuken:packr:034efe51781d2d8faa90370492133241bfb0283c/' build.gradle

    popd
  '';

  preBuild = ''
    export GRADLE_USER_HOME=$(mktemp -d)
  '';

  # The default one still uses jdk8 (#89731)
  gradle_6 = (gradleGen.override (old: { java = jdk; })).gradle_6_7;

  # fake build to pre-download deps into fixed-output derivation
  deps = stdenv.mkDerivation {
    pname = "${pname}-deps";
    inherit version unpackPhase patches;
    postPatch = cleanupMindustrySrc;

    nativeBuildInputs = [ gradle_6 perl ];
    # Here we download dependencies for both the server and the client so
    # we only have to specify one hash for 'deps'. Deps can be garbage
    # collected after the build, so this is not really an issue.
    buildPhase = preBuild + ''
      pushd Mindustry
      gradle --no-daemon resolveDependencies
      popd
    '';
    # perl code mavenizes pathes (com.squareup.okio/okio/1.13.0/a9283170b7305c8d92d25aff02a6ab7e45d06cbe/okio-1.13.0.jar -> com/squareup/okio/okio/1.13.0/okio-1.13.0.jar)
    installPhase = ''
      find $GRADLE_USER_HOME/caches/modules-2 -type f -regex '.*\.\(jar\|pom\)' \
        | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/$x/$3/$4/$5" #e' \
        | sh
    '';
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "09rwyrg2yv8r499b0dk1bzvymsf98d4j5b95bwd9s4xvrz71is3l";
  };

in
assert stdenv.lib.assertMsg (enableClient || enableServer)
  "mindustry: at least one of 'enableClient' and 'enableServer' must be true";
stdenv.mkDerivation rec {
  inherit pname version unpackPhase patches;

  postPatch = ''
    # ensure the prebuilt shared objects don't accidentally get shipped
    rm Arc/natives/natives-desktop/libs/libarc*.so
    rm Arc/backends/backend-sdl/libs/linux64/libsdl-arc*.so
  '' + cleanupMindustrySrc;

  buildInputs = [
    SDL2
    glew
    alsaLib
  ];
  nativeBuildInputs = [
    pkg-config
    gradle_6
    makeWrapper
    jdk
    ant
    copyDesktopItems
  ];

  desktopItems = [ desktopItem ];

  buildPhase = with stdenv.lib; preBuild + ''
    # point to offline repo
    sed -ie "s#mavenLocal()#mavenLocal(); maven { url '${deps}' }#g" Mindustry/build.gradle
    sed -ie "s#mavenCentral()#mavenCentral(); maven { url '${deps}' }#g" Arc/build.gradle

    pushd Mindustry
  '' + optionalString enableClient ''
    gradle --offline --no-daemon jnigenBuild -Pbuildversion=${buildVersion}
    gradle --offline --no-daemon sdlnatives -Pdynamic -Pbuildversion=${buildVersion}
    patchelf ../Arc/backends/backend-sdl/libs/linux64/libsdl-arc*.so \
      --add-needed ${glew.out}/lib/libGLEW.so \
      --add-needed ${SDL2}/lib/libSDL2.so
    gradle --offline --no-daemon desktop:dist -Pbuildversion=${buildVersion}
  '' + optionalString enableServer ''
    gradle --offline --no-daemon server:dist -Pbuildversion=${buildVersion}
  '';

  installPhase = with stdenv.lib; optionalString enableClient ''
    install -Dm644 desktop/build/libs/Mindustry.jar $out/share/mindustry.jar
    mkdir -p $out/bin
    makeWrapper ${jdk}/bin/java $out/bin/mindustry \
      --add-flags "-jar $out/share/mindustry.jar"
    install -Dm644 core/assets/icons/icon_64.png $out/share/icons/hicolor/64x64/apps/mindustry.png
  '' + optionalString enableServer ''
    install -Dm644 server/build/libs/server-release.jar $out/share/mindustry-server.jar
    mkdir -p $out/bin
    makeWrapper ${jdk}/bin/java $out/bin/mindustry-server \
      --add-flags "-jar $out/share/mindustry-server.jar"
  '';

  meta = with lib; {
    homepage = "https://mindustrygame.github.io/";
    downloadPage = "https://github.com/Anuken/Mindustry/releases";
    description = "A sandbox tower defense game";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ fgaz petabyteboy ];
    platforms = platforms.x86_64;
    # Hash mismatch on darwin:
    # https://github.com/NixOS/nixpkgs/pull/105590#issuecomment-737120293
    broken = stdenv.isDarwin;
  };
}
