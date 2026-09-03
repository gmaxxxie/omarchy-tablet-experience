// BoundedProcess.qml — Quickshell.Io.Process with a hard deadline and a byte
// cap on collected stdout, so a wedged or noisy probe can never stall the
// pollers forever or grow memory without bound (security review, finding 3).
//
// Drop-in replacement for the plugin's probe pattern:
//
//   BoundedProcess {
//     id: probe
//     command: ["hyprctl", "monitors", "-j"]
//     onStreamFinished: { /* use `output` (capped), not `text` */ }
//   }
//
// Properties (mirror Process where call sites use them):
//   running     — start/stop the inner process (alias). A process that exits
//                 naturally flips it back to false, so the pollers'
//                 `if (!X.running) X.running = true` guard keeps working.
//   command     — the command to run (alias).
//   deadlineMs  — SIGKILL the process if it is still running after this many
//                 ms (default 5000). A hung probe no longer blocks the polls.
//   maxBytes    — kill the process once its stdout exceeds this many bytes
//                 (default 65536). Output past the cap is discarded and
//                 `overflow` is set; a misbehaving producer cannot grow the
//                 collector without bound.
//   output      — the collected stdout, truncated at maxBytes.
//   overflow    — true when the producer was killed for exceeding maxBytes.
// Signal:
//   streamFinished — emitted exactly once per run (normal exit, timeout, or
//                 overflow), so pollers always move on.
//
// Implemented as an invisible Item wrapper (its `data` default property holds
// the child Process + watchdog Timer) rather than a Process subclass because
// Quickshell's Process has no default property.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: bp

  property alias command: proc.command
  property alias running: proc.running
  property int deadlineMs: 5000
  property int maxBytes: 65536
  property string output: ""
  property bool overflow: false
  property bool _done: false
  signal streamFinished()

  Process {
    id: proc
    onRunningChanged: {
      if (proc.running) {
        bp._done = false
        bp.overflow = false
        bp.output = ""
      }
    }
    stdout: StdioCollector {
      id: cap
      waitForEnd: true
      onDataChanged: {
        if (cap.data.length > bp.maxBytes) {
          bp.overflow = true
          bp.killNow()
        } else {
          bp.output = cap.text
        }
      }
      onStreamFinished: bp.finish(false)
    }
  }

  // Watchdog: a process that never exits gets SIGKILL'd after deadlineMs.
  Timer {
    id: watchdog
    interval: bp.deadlineMs
    running: bp.running
    repeat: false
    onTriggered: {
      if (bp.running) bp.killNow()
    }
  }

  function killNow() {
    // Kill the child (SIGKILL) and stop the Process, then always signal the
    // consumer so a timeout/overflow never leaves a poller waiting forever.
    proc.signal(9)
    proc.running = false
    bp.finish(true)
  }

  function finish(killed) {
    if (bp._done) return
    bp._done = true
    if (!killed && !bp.overflow) bp.output = cap.text
    bp.streamFinished()
  }
}
