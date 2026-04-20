import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Power
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  // --- Live state mirrored from `system-awake status --json` ---
  property bool active: false
  property string scope: "partial"
  property string durationLabel: ""
  property var endEpoch: null  // null → unlimited; number → expiry unix seconds
  property bool thermalGuardActive: false

  // Suppress the enable/disable toast on the first status apply so a session
  // already running when the shell starts doesn't spuriously "enable" us.
  property bool _firstStatusApplied: false

  // Unix-ms timestamp of the last `start` issued by this plugin. Used to
  // suppress the transient active=false window during a reconfigure
  // (the shell's cleanup_inactive removes state.json before writing the
  // new one), which otherwise makes the widget flicker off→on.
  property real _lastStartMs: 0

  // Derived from endEpoch so the countdown ticks with the global Time singleton
  // (free clock-skew / resume handling).
  readonly property int remainingSeconds: {
    if (!active) return 0;
    if (endEpoch === null) return -1;  // unlimited sentinel
    return Math.max(0, endEpoch - Time.timestamp);
  }

  // --- Idle inhibitor (full scope only) ---
  property bool _idleHeld: false

  onActiveChanged: {
    _syncIdle();
    if (_firstStatusApplied) {
      if (active) {
        const label = (endEpoch === null) ? "∞" : durationLabel;
        const desc = scope + " · " + label
                   + (scope === "full" ? " · display on" : " · display may sleep");
        ToastService.showNotice("Keep Awake on", desc, "coffee");
      } else {
        ToastService.showNotice("Keep Awake off", "", "coffee-off");
      }
    }
  }
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
    // Assign `active` LAST. The derived `remainingSeconds` reads
    // `active && endEpoch === null` as the unlimited sentinel, so if
    // `active` flipped true before `endEpoch` updates, the stale null
    // would briefly surface as ∞ in bindings and `onActiveChanged`.
    if (!s.active) {
      // Reconfigure race: if we just issued `start` while active, the shell
      // briefly tears state down before writing the new state. Ignore the
      // transient off window so the bar widget doesn't flicker.
      if (root.active && (Date.now() - root._lastStartMs) < 2000) return;
      root.scope = "";
      root.durationLabel = "";
      root.endEpoch = null;
      root.active = false;
    } else {
      root.scope = s.scope;
      root.durationLabel = s.duration_label;
      root.endEpoch = (s.end_epoch === null || s.end_epoch === undefined) ? null : Number(s.end_epoch);
      root.active = true;
    }
    root._firstStatusApplied = true;
  }

  // --- Actions (invoked by BarWidget / Panel) ---
  // All shell invocations pass --silent; state-change toasts are fired from
  // `onActiveChanged` above so they trigger for external `system-awake`
  // callers too (CLI, keybind) without the shell also firing notify-send.
  // Mirrors the shell's format_label so the optimistic durationLabel
  // matches what the next poll will write — otherwise the panel's
  // label-based minutes match fails briefly during reconfigure.
  function _shellLabel(seconds) {
    if (seconds === -1) return "∞";
    if (seconds >= 3600) {
      const h = Math.floor(seconds / 3600);
      const m = Math.floor((seconds % 3600) / 60);
      if (m === 0) return h + "h";
      return h + "h" + (m < 10 ? "0" + m : m) + "m";
    }
    return Math.floor(seconds / 60) + "m";
  }

  function start(durationSeconds, pickScope) {
    // `timeout 0s` in GNU coreutils means unlimited, so reject any
    // non-positive duration except the explicit -1 "unlimited" sentinel.
    const d = durationSeconds;
    if (d !== -1 && (!Number.isFinite(d) || d < 1)) {
      console.warn("keep-awake-plus: refused start with invalid duration:", d);
      return;
    }
    const durArg = (d === -1) ? "unlimited" : String(Math.floor(d));
    root._lastStartMs = Date.now();

    // Optimistic update: reflect the new state immediately so the bar
    // icon color + countdown update on click, not 100-300ms later when
    // the shell finishes writing state.json. The next poll confirms.
    root.scope = pickScope;
    root.durationLabel = _shellLabel(d);
    root.endEpoch = (d === -1) ? null : Math.floor(Date.now() / 1000) + Math.floor(d);
    root.active = true;

    Quickshell.execDetached(["system-awake", "start", durArg, "--scope=" + pickScope, "--silent"]);
    Qt.callLater(root._pollStatus);
  }

  function off() {
    // Optimistic update so the bar widget flips to "off" immediately.
    root.scope = "";
    root.durationLabel = "";
    root.endEpoch = null;
    root.active = false;
    Quickshell.execDetached(["system-awake", "off", "--silent"]);
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
