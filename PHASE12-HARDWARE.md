# Phase 12 — Hardware Full Bring-up

Priority per user: **camera first**. Verified 2026-08-29.

## Camera — VERIFIED WORKING (UVC path), IPU6/CSI path = dead end on this hw

### Hardware truth

`174f:118f` Syntek is a **USB camera bridge** (SunplusIT bridge; udev id
`SunplusIT_Inc_Integrated_RGB_Camera`). One physical device exposes **two UVC
functions** on USB `3-4`:

| Function | Node | Format | Notes |
|---|---|---|---|
| RGB (UVC 1.50) | `/dev/video64` (meta: `video65`) | MJPG 2592x1944 → 320x180 @30fps | real scene verified |
| IR | `/dev/video66` (meta: `video67`) | GREY 640x480 @15/30fps | IR camera (Windows Hello class) verified |
| media | `/dev/media1` + `/dev/media2` | uvcvideo | |

### Why the IPU6 CSI path is a dead end (do NOT pursue the AUR HAL)

- Kernel logs at boot: `IPU6 in secure mode`, `ov8856 i2c-OVTI8856:00: failed
  to find sensor: -5` (EIO), `auxiliary intel_ipu6.psys: Failed to get runtime PM`.
- The IPU6 (Tiger Lake) firmware refuses the secure-mode authenticate path on
  this board, and the sensor sits behind the Syntek USB bridge, so the
  `ov8856` sensor can never probe on the I2C/CSI2 side.
- Consequences: `/dev/video0–63` (`isys` driver, `media0`) are raw sensor
  capture nodes with `MUST_CONNECT` filters — **not usable by apps**; psys is
  inert; installing `intel-ipu6-camera-hal/bins` (AUR) cannot help because the
  CSE refuses. **UVC is the correct and complete path.**
- (Optionally: blacklist `intel-ipu6` module to declutter 64 junk nodes —
  deferred, it's cosmetic and reversible.)

### Verification performed

```sh
v4l2-ctl -d /dev/video64 --set-fmt-video=width=1280,height=720,pixelformat=MJPG \
  --stream-mmap --stream-count=5 --stream-to=/tmp/cam_test.mjpg   # 722942 bytes, JPEG ✓
v4l2-ctl -d /dev/video64 --info   # Driver uvcvideo, 0x04200001
v4l2-ctl -d /dev/video64 --list-formats-ext
v4l2-ctl -d /dev/video66 --set-fmt-video=width=640,height=480,pixelformat=GREY \
  --stream-mmap --stream-count=1 --stream-to=/tmp/cam_ir.raw      # 307200 bytes ✓
```

- RGB frame `verify/cam-rgb-1280x720.jpg` (145KB) — pixel stats mean≈108
  (0.42), σ≈41 → **real scene, not black**.
- IR frame stats: mean 48.7, σ 28.3 → real signal.
- Permissions: user `maxt` has ACL rw on the video nodes (`getfacl /dev/video64`
  → `user:maxt:rw-`), no `video` group membership needed.

### Remaining for app-facing use (browser / omarchy apps) — needs 1 install

- PipeWire's v4l2 monitor currently only exposes the *isys* nodes; the UVC
  device is invisible to it, and xdg-desktop-portal (which ships a built-in
  PipeWire camera backend) therefore cannot present the camera to Chromium etc.
- Standard fix (official `extra`): **`sudo pacman -S libcamera`** → WirePlumber
  picks UVC cameras up as real camera nodes; then test in Chromium
  (`https://webcamtests.com` or any video-call app).
- `gst-launch-1.0` lacks `v4l2src` on this box (`gst-plugins-good` not
  installed) — optional install if gst pipelines are wanted.
- **Not done yet:** libcamera install required interactive sudo (fingerprint
  prompt timed out in this session). Portal camera status = VERIFIED-AWAITING-INSTALL.

## Fingerprint — VERIFIED (already enrolled)

- `fprintd 1.94.5-2`, device Synaptics Prometheus `06cb:00bd`.
- `fprintd-list maxt` → 1 device, fingerprint `#0: right-index-finger` enrolled.
- Live proof: `sudo` triggered PAM fingerprint prompt ("Place your right index
  finger on the fingerprint reader") — the reader responds to the system.
- Pending user test: unlock via `sudo`/login with the enrolled finger.

## Bluetooth — VERIFIED (discovery)

- AX201 `8087:0026`, controller `F0:57:A6:D5:95:AC` up (`bluetoothctl show`).
- 10s passive scan discovered 13+ devices (incl. named ones like `U-GWH71B2`,
  `LuYuan-Smart`) → radio + stack fine.
- Pending user test: pair an actual device (earbuds/phone).

## Audio — VERIFIED

- SOF card 0 (`sof-hda-dsp`, ALC287 codec), firmware `sof-firmware 2025.12.2-1`,
  topology loaded cleanly per kernel log.
- WirePlumber nodes present:
  - Sinks: Speaker (default, vol 0.40) + HDMI 1/2/3 outputs
  - Sources: Stereo Microphone + Digital Microphone
- Cosmetic: `mod.rt: RTKit error` at startup → audio threads lack realtime
  priority (needs `rtkit`/polkit; harmless for normal use).

## Phase 12 status board

| Device | Status | Next step |
|---|---|---|
| Camera RGB + IR (UVC) | ✅ output verified | `pacman -S libcamera` → browser test |
| Fingerprint | ✅ enrolled + reader live | user unlocks with finger |
| Bluetooth AX201 | ✅ controller + scan | user pairs a device |
| Audio SOF | ✅ sinks/sources present | user playback/capture check |
| IPU6 CSI (isys nodes) | ❌ dead end (secure mode) | leave as-is; optional module blacklist |