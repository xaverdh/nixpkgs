{ stdenv, fetchurl, xorg, x11 }:

let version = "1.2.sakura.5";
    vname = "1.2.5";
in stdenv.mkDerivation rec {
  name = "oneko-" + vname;
  src = fetchurl {
    url = "http://www.daidouji.com/oneko/distfiles/oneko-"
          + version + ".tar.gz";
    sha256 = "2c2e05f1241e9b76f54475b5577cd4fb6670de058218d04a741a04ebd4a2b22f";
  };
  buildInputs = [ xorg.imake xorg.gccmakedep x11 ];
  imake = xorg.imake;
  gccmakedep = xorg.gccmakedep;
  
  builder = builtins.toFile "builder.sh" ''
   source $stdenv/setup
   PATH=$imake/bin:$PATH
   PATH=$gccmakedep/bin:$PATH

   tar xf $src
   cd oneko-*
   
   xmkmf -a
   make
   BINDIR=/bin make -e DESTDIR=$out install

   mkdir -p $out/share/man/man1
   mkdir -p $out/share/man/jp/man1
   cp oneko.man $out/share/man/man1/oneko.1
   cp oneko.man.jp $out/share/man/jp/man1/oneko.1
  '';
  
  meta = with stdenv.lib; {
    description = "Creates a cute cat chasing around your mouse cursor";
    longDescription = ''
    Oneko changes your mouse cursor into a mouse
    and creates a little cute cat, which starts
    chasing around your mouse cursor.
    When the cat is done catching the mouse, it starts sleeping.
    '';
    homepage = "http://www.daidouji.com/oneko/";
    license = licenses.publicDomain;
    maintainers = [ maintainers.xaverdh ];
    meta.platforms = platforms.unix;
  };
}

