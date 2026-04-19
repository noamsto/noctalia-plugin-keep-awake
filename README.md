# Keep Awake+

Noctalia plugin. Replaces the built-in `KeepAwake` widget with a richer control:

- Two scopes: **partial** (suspend + lid inhibit, monitor may sleep) and **full** (everything).
- Menu-driven duration picker with configurable defaults.
- Persistent last-choice: middle-click re-activates your last duration+scope.
- Dynamic tooltip showing remaining time and thermal-guard state.

Backed by a host-side `system-awake` script (see `https://github.com/noamsto/nix-config`).
