import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Power

Item {
  id: root
  property var pluginApi: null

  // --- Live state mirrored from `system-awake status --json` ---
  property bool active: false
  property string scope: "partial"
  property string durationLabel: ""
  property var endEpoch: null  // null for unlimited, number otherwise
  property int remainingSeconds: 0
  property bool thermalGuardActive: false

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

  // --- Poller ---
  Process {
    id: statusProc
    running: false
    command: ["system-awake", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const s = JSON.parse(this.text.trim() || "{}");
          root._applyStatus(s);
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

  Timer {
    id: poller
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: { statusProc.running = true; guardProc.running = true; }
  }

  // Countdown decrement between polls, to avoid visible jitter.
  Timer {
    interval: 1000
    repeat: true
    running: root.active && root.endEpoch !== null
    onTriggered: {
      if (root.endEpoch === null) return;
      const now = Math.floor(Date.now() / 1000);
      root.remainingSeconds = Math.max(0, root.endEpoch - now);
    }
  }

  function _applyStatus(s) {
    if (!s.active) {
      root.active = false;
      root.scope = "";
      root.durationLabel = "";
      root.endEpoch = null;
      root.remainingSeconds = 0;
      return;
    }
    root.active = true;
    root.scope = s.scope;
    root.durationLabel = s.duration_label;
    if (s.end_epoch === null || s.end_epoch === undefined) {
      root.endEpoch = null;
      root.remainingSeconds = -1;  // signal "unlimited" to view layer
    } else {
      root.endEpoch = Number(s.end_epoch);
      const now = Math.floor(Date.now() / 1000);
      root.remainingSeconds = Math.max(0, root.endEpoch - now);
    }
  }

  // --- Actions (invoked by BarWidget / Panel) ---
  function start(durationSeconds, pickScope) {
    const durArg = (durationSeconds === -1) ? "unlimited" : String(durationSeconds);
    Quickshell.execDetached(["system-awake", "start", durArg, "--scope=" + pickScope]);
    Qt.callLater(() => { statusProc.running = true; });
  }

  function off() {
    Quickshell.execDetached(["system-awake", "off"]);
    Qt.callLater(() => { statusProc.running = true; });
  }

  function extend(seconds) {
    Quickshell.execDetached(["system-awake", "extend", String(seconds)]);
    Qt.callLater(() => { statusProc.running = true; });
  }

  function toggleLast() {
    Quickshell.execDetached(["system-awake", "toggle-last"]);
    Qt.callLater(() => { statusProc.running = true; });
  }

  function formatRemaining() {
    if (!active) return "";
    if (remainingSeconds === -1) return "∞";
    const m = Math.floor(remainingSeconds / 60);
    if (m >= 60) return Math.floor(m / 60) + "h" + String(m % 60).padStart(2, "0") + "m";
    return m + "m";
  }
}
