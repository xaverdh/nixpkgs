{
  lib,
  buildPackages,
  fetchurl,
  perl,
  buildLinux,
  sha256,
  branch,
  rc ? null,
  date ? null,
  modDirVersion ? null,
  ... } @ args:

let
  minus = s: lib.optionalString (s != null) "-${s}";
  variant = if date != null then "next-${date}" else "${branch}${minus rc}";
  version = "${branch}.0${minus rc}" + lib.optionalString (date != null) "-next";
in

buildLinux (args // {
  inherit version;

  modDirVersion = if modDirVersion == null
    then "${version}${minus date}"
    else modDirVersion;

  src = fetchurl {
    url = "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/snapshot/linux-next-${variant}.tar.gz";
    inherit sha256;
  };

} // (args.argsOverride or {}))
