import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Power

Item {
  id: root
  property var pluginApi: null

  // --- Live state mirrored from `system-awake status --json` ---
  property bool active: false
  property string scope: "partial"
  property string durationLabel: ""
  property var endEpoch: null  // null → unlimited; number → expiry unix seconds
  property bool thermalGuardActive: false

  // Derived from endEpoch so the countdown ticks with the global Time singleton
  // (free clock-skew / resume handling).
  readonly property int remainingSeconds: {
    if (!active) return 0;
    if (endEpoch === null) return -1;  // unlimited sentinel
    return Math.max(0, endEpoch - Time.timestamp);
  }

  // --- Idle inhibitor (full scope only) ---
  property bool _idleHeld: false

  onActiveChanged: _syncIdle()
  onScopeChanged: _syncIdle()

  function _syncIdle() {
    const shouldHold = active && scope === "full";
    if (shouldHold && !_idleHeld) {
      IdleInhibitorService.addInhibitor("keep-awake-plus", "Keep Awake+ full scope");
      _idleHeld = true;
    } else if (!shouldHold && _idleHeld) {
      IdleInhibitorService.removeInhibitor("keep-awake-plus");
      _idleHeld = false;
    }
  }

  Component.onDestruction: {
    if (_idleHeld) IdleInhibitorService.removeInhibitor("keep-awake-plus");
  }

  // --- Settings (from manifest metadata + pluginApi overrides) ---
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property string defaultScope: cfg.defaultScope ?? defaults.defaultScope ?? "partial"
  property var durations: cfg.durations ?? defaults.durations ?? [30, 60, 120, 240, 480]
  property bool includeUnlimited: cfg.includeUnlimited ?? defaults.includeUnlimited ?? true
  property bool showRemainingText: cfg.showRemainingText ?? defaults.showRemainingText ?? true
  property bool activateOnLeftClick: cfg.activateOnLeftClick ?? defaults.activateOnLeftClick ?? false
  property int quickExtendMinutes: cfg.quickExtendMinutes ?? defaults.quickExtendMinutes ?? 30

  // --- Pollers ---
  Process {
    id: statusProc
    running: false
    command: ["system-awake", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root._applyStatus(JSON.parse(this.text.trim() || "{}"));
        } catch (e) {
          console.warn("keep-awake-plus: failed to parse status:", e, "text:", this.text);
        }
      }
    }
  }

  Process {
    id: guardProc
    running: false
    command: ["systemctl", "--user", "is-active", "--quiet", "system-awake-thermal-guard.service"]
    onExited: function(exitCode) { root.thermalGuardActive = (exitCode === 0); }
  }

  function _pollStatus() { if (!statusProc.running) statusProc.running = true; }
  function _pollGuard()  { if (!guardProc.running)  guardProc.running  = true; }

  Timer {
    id: statusPoller
    interval: 1000; repeat: true; running: true; triggeredOnStart: true
    onTriggered: root._pollStatus()
  }

  // Thermal-guard state changes on minute-scale and is only read on tooltip
  // hover, so polling it every second is wasted process spawns.
  Timer {
    id: guardPoller
    interval: 15000; repeat: true; running: true; triggeredOnStart: true
    onTriggered: root._pollGuard()
  }

  function _applyStatus(s) {
    if (!s.active) {
      root.active = false;
      root.scope = "";
      root.durationLabel = "";
      root.endEpoch = null;
      return;
    }
    root.active = true;
    root.scope = s.scope;
    root.durationLabel = s.duration_label;
    root.endEpoch = (s.end_epoch === null || s.end_epoch === undefined) ? null : Number(s.end_epoch);
  }

  // --- Actions (invoked by BarWidget / Panel) ---
  // `silent` suppresses the shell-script notification. Used by the panel when
  // reconfiguring an already-active session so the user doesn't get a toast
  // per click.
  function start(durationSeconds, pickScope, silent) {
    // Guard: `timeout 0s` in GNU coreutils means unlimited. Reject any
    // non-positive duration except the explicit -1 "unlimited" sentinel.
    const d = durationSeconds;
    if (d !== -1 && (!Number.isFinite(d) || d < 1)) {
      console.warn("keep-awake-plus: refused start with invalid duration:", d);
      return;
    }
    const durArg = (d === -1) ? "unlimited" : String(Math.floor(d));
    const args = ["system-awake", "start", durArg, "--scope=" + pickScope];
    if (silent) args.push("--silent");
    Quickshell.execDetached(args);
    Qt.callLater(root._pollStatus);
  }

  function off(silent) {
    const args = ["system-awake", "off"];
    if (silent) args.push("--silent");
    Quickshell.execDetached(args);
    Qt.callLater(root._pollStatus);
  }

  function extend(seconds) {
    Quickshell.execDetached(["system-awake", "extend", String(seconds)]);
    Qt.callLater(root._pollStatus);
  }

  function toggleLast() {
    Quickshell.execDetached(["system-awake", "toggle-last"]);
    Qt.callLater(root._pollStatus);
  }

  function formatRemaining() {
    if (!active) return "";
    if (remainingSeconds === -1) return "∞";
    return Time.formatVagueHumanReadableDuration(remainingSeconds);
  }
}
