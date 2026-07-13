# Makes dinit the stage-2 PID 1 in a finix system.
#
# finix puts system.topLevel/init → ${finit.package}/bin/finit.  This module
# overrides finit.package with a compiled C binary that:
#   1. reads argv[0] from /proc/self/cmdline — the kernel preserves the
#      original init= path in argv[0] even after symlink resolution, the same
#      trick used by finix-setup.c — and calls dirname to get the topLevel
#   2. fork/execs <topLevel>/activate
#   3. creates /run/{booted,current}-system symlinks
#   4. exec's dinit so it becomes the true stage-2 PID 1
#
# Requires the dinit module to also be imported and dinit.enable = true so
# that service files and the boot target are laid down by activation.

{ lib, pkgs, ... }:
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

    int main(void) {
      char cmdline[PATH_MAX];
      char sysconfig[PATH_MAX];
      char *copy;
      int fd;
      ssize_t n;
      char *const dinit_argv[] = {
        (char *)DINIT_BIN, "-d", (char *)DINIT_SVCDIR, "boot", (char *)NULL
      };

      fd = open("/proc/self/cmdline", O_RDONLY);
      if (fd < 0) { perror("open /proc/self/cmdline"); return 1; }
      n = read(fd, cmdline, sizeof(cmdline) - 1);
      close(fd);
      if (n <= 0) { perror("read /proc/self/cmdline"); return 1; }
      cmdline[n] = '\0';

      copy = strdup(cmdline);
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

  drv = pkgs.stdenv.mkDerivation {
    pname = "dinit-stage2-init";
    # Satisfies the `lib.versionAtLeast cfg.package.version "4.16"` assertion
    # in the finix finit module, whose package slot we're borrowing.
    version = "4.99.0";
    dontUnpack = true;
    buildPhase = ''$CC -o finit ${src}'';
    installPhase = ''install -Dm755 finit $out/bin/finit'';
  };

  # finix's finit.package apply calls:
  #   (package.override { plymouthSupport = …; }).overrideAttrs (o: { configureFlags = …; })
  # stdenv.mkDerivation doesn't get .override (that comes from callPackage), so
  # we stub both to return our binary unchanged.
  initPkg = drv // {
    override = _: drv // { overrideAttrs = _: drv; };
  };
in
{
  finit.package = lib.mkForce initPkg;
}
