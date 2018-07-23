{ stdenv, fetchFromGitHub, cmake, fuse, readline, pkgconfig }:

stdenv.mkDerivation rec {
  name = "android-file-transfer-${version}";
  version = "3.4";
  src = fetchFromGitHub {
    owner = "whoozle";
    repo = "android-file-transfer-linux";
    rev = "v${version}";
    sha256 = "1xwl0vk57174gdjhgqkzrirwzd2agdm84q30dq9q376ixgxjrifc";
  };
  buildInputs = [ cmake fuse readline pkgconfig ];
  buildPhase = ''
    cmake -DBUILD_QT_UI=OFF .
    make
  '';
  installPhase = ''
    make install
  '';
  meta = with stdenv.lib; {
    description = "Reliable MTP client with minimalistic UI";
    homepage = http://whoozle.github.io/android-file-transfer-linux/;
    license = licenses.lgpl21;
    maintainers = [ maintainers.xaverdh ];
    platforms = platforms.linux;
  };
}
