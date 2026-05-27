{
  stdenv,
  qemu,
  glib,
  pkg-config,
}:

stdenv.mkDerivation {
  pname = "qemu-ft-fuzz-plugin";
  version = "0.1.0";

  src = ../plugins/qemu-ft-fuzz;

  strictDeps = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    qemu
    glib
  ];

  buildPhase = ''
    runHook preBuild

    $CC -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared -fvisibility=hidden \
      -I${qemu}/include \
      $(pkg-config --cflags glib-2.0) \
      qemu-ft-fuzz.c \
      -o qemu-ft-fuzz.so \
      $(pkg-config --libs glib-2.0)

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 qemu-ft-fuzz.so "$out/lib/qemu-ft-fuzz.so"

    runHook postInstall
  '';
}
