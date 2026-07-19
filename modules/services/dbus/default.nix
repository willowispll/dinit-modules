{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.dbus-dinit;

  homeDir = "/run/dbus";

  configDir = pkgs.makeDBusConf.override {
    suidHelper = "${config.security.wrapperDir}/dbus-daemon-launch-helper";
    serviceDirectories = cfg.packages;
  };
in
{
  options.services.dbus-dinit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [dbus](${pkgs.dbus.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dbus;
      defaultText = lib.literalExpression "pkgs.dbus";
      apply =
        package:
        if cfg.debug then
          package.overrideAttrs (o: {
            configureFlags = o.configureFlags ++ [ "--enable-verbose-mode" ];
          })
        else
          package;
      description = ''
        The package to use for `dbus`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Packages whose D-Bus configuration files should be included in
        the configuration of the D-Bus system-wide or session-wide
        message bus.  Specifically, files in the following directories
        will be included into their respective DBus configuration paths:
        {file}`«pkg»/etc/dbus-1/system.d`
        {file}`«pkg»/share/dbus-1/system.d`
        {file}`«pkg»/share/dbus-1/system-services`
        {file}`«pkg»/etc/dbus-1/session.d`
        {file}`«pkg»/share/dbus-1/session.d`
        {file}`«pkg»/share/dbus-1/services`
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."dbus-1".source = configDir;

    environment.pathsToLink = [
      "/etc/dbus-1"
      "/share/dbus-1"
    ];

    users.users = {
      messagebus = {
        description = "D-Bus system message bus daemon user";
        home = homeDir;
        group = "messagebus";
      };
    };

    users.groups = {
      messagebus = { };
    };

    environment.systemPackages = [
      cfg.package
    ];

    services.dbus-dinit.packages = [
      cfg.package
      config.environment.path
    ];

    security.wrappers.dbus-daemon-launch-helper = {
      source = "${cfg.package}/libexec/dbus-daemon-launch-helper";
      owner = "root";
      group = "messagebus";
      setuid = true;
      setgid = false;
      permissions = "u+rx,g+rx,o-rx";
    };

    dinit.services.dbus = {
      type = "process";
      command = "${cfg.package}/bin/dbus-daemon --nofork --system --syslog-only";
      waits-for = [ "syslogd" ];
      restart = true;
      smooth-recovery = true;
      boot = false;
      default = true;

      environment = lib.optionalAttrs cfg.debug {
        DBUS_VERBOSE = "1";
      };
    };

    system.activation.scripts.dbus = {
      deps = [ "specialfs" ];
      text = ''
        mkdir -p /run/dbus
        mkdir -p /run/lock/subsys
        mkdir -p /var/lib/dbus
        mkdir -p /tmp/dbus

        ${cfg.package}/bin/dbus-uuidgen --ensure

        if [ ! -e /etc/machine-id ]; then
          ln -sf /var/lib/dbus/machine-id /etc/machine-id
        fi
      '';
    };
  };
}
