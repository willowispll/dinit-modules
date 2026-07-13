{ config, lib, pkgs, ... }:
let
  src = pkgs.writeText "dinit-init.c" ''
    #include <fcntl.h>
    #include <libgen.h>
    #include <limits.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <unistd.h>
    #include <sys/stat.h>
    #include <sys/types.h>
    #include <sys/wait.h>

    static const char DINIT_BIN[]    = "${lib.getExe pkgs.dinit}";
    static const char DINIT_SVCDIR[] = "/etc/dinit.d";

    static void run_activation(const char *sysconfig) {
      char activate[PATH_MAX];
      pid_t pid;
      int status;
      snprintf(activate, sizeof(activate), "%s/activate", sysconfig);
      pid = fork();
      if (pid == 0) {
        char *const argv[] = { activate, (char *)NULL };
        execv(activate, argv);
        perror("execv activate");
        _exit(127);
      }
      if (pid < 0) { perror("fork"); return; }
      waitpid(pid, &status, 0);
    }

    static void setup_run_symlinks(const char *sysconfig) {
      mkdir("/run", 0755);
      unlink("/run/booted-system");
      unlink("/run/current-system");
      symlink(sysconfig, "/run/booted-system");
      symlink(sysconfig, "/run/current-system");
    }

    int main(int argc, char *argv[]) {
      char sysconfig[PATH_MAX];
      char *copy;
      char *const dinit_argv[] = {
        (char *)DINIT_BIN, "-d", (char *)DINIT_SVCDIR, "boot", (char *)NULL
      };

      /*
       * Stage detection: the kernel preserves the original init= path in
       * argv[0] even after symlink resolution.  In stage 2, argv[0] is
       * /nix/store/<hash>-finix-system/init.  In the initrd (stage 1),
       * argv[0] is "init" or "/init" -- anything NOT starting with /nix/store/.
       * Delegate stage 1 to the real finit embedded at /finit-stage1 so it
       * can mount filesystems and switch_root before we take over as PID 1.
       */
      if (argc < 1 || strncmp(argv[0], "/nix/store/", 11) != 0) {
        argv[0] = "/finit-stage1";
        execv("/finit-stage1", argv);
        perror("execv /finit-stage1");
        return 1;
      }

      copy = strdup(argv[0]);
      if (!copy) { perror("strdup"); return 1; }
      strncpy(sysconfig, dirname(copy), sizeof(sysconfig) - 1);
      sysconfig[sizeof(sysconfig) - 1] = '\0';
      free(copy);

      run_activation(sysconfig);
      setup_run_symlinks(sysconfig);

      execv(DINIT_BIN, dinit_argv);
      perror("execv dinit");
      return 1;
    }
  '';

  ourBinary = pkgs.stdenv.mkDerivation {
    name = "dinit-stage2-binary";
    dontUnpack = true;
    buildPhase = ''$CC -o finit ${src}'';
    installPhase = ''install -Dm755 finit $out/bin/finit'';
  };

  # Symlink-farm of the real finit with only bin/finit replaced by our binary.
  # The finix initrd builder (src/main.rs) lstat's lib/, libexec/,
  # lib/finit/plugins/*.so, lib/finit/rescue.conf, etc., so we expose
  # the full real-finit tree to satisfy those checks.
  drv = pkgs.runCommand "dinit-stage2-init" { } ''
    mkdir -p $out/bin
    for f in ${pkgs.finit}/*; do
      name=$(basename "$f")
      [ "$name" = bin ] && continue
      ln -s "$f" "$out/$name"
    done
    for f in ${pkgs.finit}/bin/*; do
      ln -s "$f" "$out/bin/$(basename "$f")"
    done
    ln -sf ${ourBinary}/bin/finit $out/bin/finit
  '';

  # finix's finit.package apply calls:
  #   (package.override { plymouthSupport = … }).overrideAttrs (o: { configureFlags = … })
  # runCommand results don't carry .override, so we stub both to return drv unchanged.
  initPkg = drv // {
    version = pkgs.finit.version;
    override = _: drv // { overrideAttrs = _: drv; };
  };
in
{
  finit.package = lib.mkForce initPkg;

  # Embed real finit in the initrd at /finit-stage1.  Our binary delegates to
  # it during stage 1 (before the 9p nix-store mount is available) so finit
  # can run its normal filesystem setup and switch_root, after which the kernel
  # re-execs init= and we start dinit as stage-2 PID 1.
  boot.initrd.contents = [
    {
      target = "/finit-stage1";
      source = "${pkgs.finit}/bin/finit";
    }
  ];
}
