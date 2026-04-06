# Smack Attack

Smack your MacBook. Hear a scream.

Listens to your microphone and plays the [Wilhelm Scream](https://en.wikipedia.org/wiki/Wilhelm_scream) whenever it detects a sudden impact — like smacking the side of your laptop.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/kimalex415/smack-attack/main/install.sh | bash
```

Requires macOS 12+. No Xcode or Swift needed.

> On first start, macOS will ask for microphone permission — click **Allow**.

---

## Usage

```bash
smack start      # Start listening in the background
smack stop       # Stop
smack status     # Check if it's running
smack uninstall  # Remove smack from your system
```

---

## Tuning

Edit the top of `smack.swift` and rebuild:

```swift
let threshold: Float = 0.15      // lower = more sensitive
let cooldown: TimeInterval = 1.5  // min seconds between screams
```

Rebuild with:
```bash
swiftc smack.swift -o smack -target arm64-apple-macosx12.0
# or x86_64-apple-macosx12.0 for Intel Macs
```

---

## How it works

Uses `AVAudioEngine` to tap the microphone, calculates RMS amplitude per buffer, and fires `afplay` to play `~/.smack-attack/wilhelm.mp3` when a spike exceeds the threshold. The sound file is downloaded automatically on first run.

---

## Uninstall

```bash
smack uninstall
```
