{ config, lib, pkgs, ... }:

with lib;

let
   cfg = config.services.dunst;
in {

options.services.dunst = {

  enable = mkEnableOption "the dunst notifications daemon";

  iconDirs = mkOption {
    type = with types; listOf path;
    default = [];
    example = literalExample ''
      [ "''${pkgs.gnome3.adwaita-icon-theme}/share/icons/Adwaita/48x48" ]
    '';
    description = ''
      Paths to icon folders.
    '';
  };

  extraCliOptions = mkOption {
    type = types.str;
    default = "";
    description = ''
      This gets appended verbatim to the command line of dunst.
    '';
  };

  globalConfig = mkOption {
    type = with types; nullOr (attrsOf str);
    default = null;
    description = ''
      Set the global configuration section for dunst.
    '';
  };

  shortcutConfig = mkOption {
    type = with types; nullOr (attrsOf str);
    default = null;
    description = ''
      Set the shortcut configuration for dunst.
    '';
  };

  urgencyConfig = {
    low = mkOption {
      type = with types; nullOr (attrsOf str);
      default = null;
      description = ''
        Set the low urgency section of the dunst configuration.
      '';
    };
    normal = mkOption {
      type = with types; nullOr (attrsOf str);
      default = null;
      description = ''
        Set the normal urgency section of the dunst configuration.
      '';
    };
    critical = mkOption {
      type = with types; nullOr (attrsOf str);
      default = null;
      description = ''
        Set the critical urgency section of the dunst configuration.
      '';
    };
  };

  rules = mkOption {
    type = with types; attrsOf (attrsOf str);
    default = {};
    description = ''
       Rules allow the conditional modification of notifications.

       Note that rule names may not be one of the following
       keywords already used internally:
         'global' 'experimental' 'frame' 'shortcuts',
         'urgency_low' 'urgency_normal' 'urgency_critical'

       There are 2 parts in configuring a rule: Defining when a rule
       matches and should apply (called filtering in the man page)
       and then the actions that should be taken when the rule is
       matched (called modifying in the man page).
    '';
    example = {
      signed_off = {
        appname = "Pidgin";
        summary = "*signed off*";
        urgency = "low";
        script = "pidgin-signed-off.sh";
      };
    };
  };

};

config =
  let
    dunstConfig = lib.generators.toINI {}
      ( lib.filterAttrsRecursive (n: v: v != null) allOptions );
    allOptions = {
      global = cfg.globalConfig;
      shortcut = cfg.shortcutConfig;
      urgency_normal = cfg.urgencyConfig.normal;
      urgency_low = cfg.urgencyConfig.low;
      urgency_critical = cfg.urgencyConfig.critical;
    } // cfg.rules;

    iconPath = builtins.concatStringsSep ":" cfg.iconDirs;

    dunstRC = pkgs.writeText "dunstrc" dunstConfig;

    wrapper-args = [ "-config" "${dunstRC}" "-icon_path" "${iconPath}" ];

    dunstWrapped = pkgs.writeShellScriptBin "dunst" ''
      exec ${pkgs.dunst}/bin/dunst \
        ${escapeShellArgs wrapper-args} ${cfg.extraCliOptions}
    '';

    dunstJoined = pkgs.symlinkJoin {
      name = "dunst-wrapper";
      paths = [ dunstWrapped pkgs.dunst ];
    };

    reservedSections = [
      "global" "experimental" "frame" "shortcuts"
      "urgency_low" "urgency_normal" "urgency_critical"
    ];
  in mkIf cfg.enable {

    assertions = flip mapAttrsToList cfg.rules (name: conf: {
      assertion = ! ( any (ruleName: ruleName == name) reservedSections );
      message = ''
        ${name} is a reserved keyword. Please choose
        a different name for the rule.
      '';
    });

    environment.systemPackages = [ dunstJoined ];

    systemd.user.services.dunst = {
      description = "Dunst notification daemon";
      documentation = [ "man:dunst(1)" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
        ExecStart = "${dunstJoined}/bin/dunst";
      };
      wantedBy = [ "default.target" ];
    };
  };

}
