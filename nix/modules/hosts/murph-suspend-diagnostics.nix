{
  lib,
  pkgs,
  ...
}:

# Records device power state immediately before every suspend and immediately
# after every resume, so that a suspend which never returns can be diagnosed
# afterwards.
#
# murph intermittently takes a fatal platform fault entering s2idle and lands
# in S5 rather than resuming; the kernel logs nothing past "PM: suspend entry"
# because the fault is below the level Linux can record. The only way to learn
# anything about a fatal suspend is therefore to write down the state going
# into it. A "pre" line with no matching "post" line identifies the fatal
# suspend and carries its state.
#
# See .scratch/handoff-murph-suspend.md for the investigation this supports.
let
  # xHCI controllers. c1:00.3 (XHC0) hosts the HDMI expansion card, the Goodix
  # fingerprint reader and the MediaTek Bluetooth radio, and is the controller
  # implicated by the log analysis.
  xhciControllers = [
    "0000:c1:00.3"
    "0000:c1:00.4"
    "0000:c3:00.3"
    "0000:c3:00.4"
  ];

  logFile = "/var/log/suspend-diagnostics.log";

  # Runs inside the suspend path, so it must stay cheap: sysfs reads only, no
  # journal queries, no subprocess fan-out beyond coreutils.
  snapshot = pkgs.writeShellScript "murph-suspend-snapshot" ''
    set -u

    # sleep-actions.service supplies only coreutils, findutils, gnugrep,
    # gnused and systemd, so do not depend on whatever else happens to be on
    # the ambient PATH.
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnused
      ]
    }

    phase="$1"
    log=${logFile}

    # Missing or unreadable sysfs entries must never fail a suspend.
    field() {
      if [ -r "$1" ]; then tr -d '\n' < "$1" 2>/dev/null || printf '?'; else printf '?'; fi
    }

    line="$(date -Is) phase=$phase"
    line="$line boot=$(field /proc/sys/kernel/random/boot_id)"

    # Suspend ordinal within this boot. The investigation's central finding is
    # that the first suspend after a boot has never failed while the second
    # fails ~73% of the time, so which number this is matters most.
    ok=$(field /sys/power/suspend_stats/success)
    bad=$(field /sys/power/suspend_stats/fail)
    line="$line ok=$ok fail=$bad"

    line="$line hw_sleep_total=$(field /sys/power/suspend_stats/total_hw_sleep)"
    line="$line hw_sleep_last=$(field /sys/power/suspend_stats/last_hw_sleep)"

    line="$line ac=$(field /sys/class/power_supply/ACAD/online)"
    line="$line bat=$(field /sys/class/power_supply/BAT1/capacity)"

    lid=$(cat /proc/acpi/button/lid/*/state 2>/dev/null | sed -n 's/.*state:[[:space:]]*//p' | head -1)
    line="$line lid=''${lid:-?}"

    # GPIO 0 register. Bits 28/29 are INTERRUPT_STS and WAKE_STS; an unclaimed
    # pin latching those during suspend is an open anomaly.
    gpio0='?'
    if [ -r /sys/kernel/debug/gpio ]; then
      gpio0=$(sed -n 's/^#0[[:space:]].*|//p' /sys/kernel/debug/gpio 2>/dev/null \
        | head -1 | tr -d '[:space:]')
    fi
    line="$line gpio0=''${gpio0:-?}"

    # Per-controller runtime PM. active/suspended times are cumulative ms for
    # this boot; a controller pinned awake shows suspended_time near zero.
    ${builtins.concatStringsSep "\n" (
      map (dev: ''
        d=/sys/bus/pci/devices/${dev}/power
        line="$line xhci_${dev}=$(field $d/runtime_status)/$(field $d/control)/$(field $d/runtime_active_time)/$(field $d/runtime_suspended_time)"
      '') xhciControllers
    )}

    printf '%s\n' "$line" >> "$log" 2>/dev/null || true

    # The whole point is surviving a power cut milliseconds later, so force the
    # record to stable storage rather than trusting writeback.
    sync -f "$log" 2>/dev/null || sync 2>/dev/null || true
  '';
in
{
  # /var/log is already persisted by murph-system-persistence.nix, so this
  # survives the ephemeral-root rollback without further configuration.
  systemd.tmpfiles.rules = [
    "f ${logFile} 0644 root root -"
  ];

  # powerDownCommands runs in sleep-actions.service (Before=sleep.target);
  # resumeCommands runs on the way back out.
  powerManagement.powerDownCommands = ''
    ${snapshot} pre
  '';

  powerManagement.resumeCommands = ''
    ${snapshot} post
  '';
}
