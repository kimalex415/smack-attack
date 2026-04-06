#!/usr/bin/env swift

import AVFoundation
import Foundation

// ─── Config ───────────────────────────────────────────────────────
let threshold: Float = 0.15      // sensitivity (lower = more sensitive)
let cooldown: TimeInterval = 1.5  // seconds between triggers

// ─── Paths ────────────────────────────────────────────────────────
let soundDir  = (NSHomeDirectory() as NSString).appendingPathComponent(".smack-attack")
let soundPath = (soundDir as NSString).appendingPathComponent("wilhelm.mp3")
let pidFile   = (NSHomeDirectory() as NSString).appendingPathComponent(".smack.pid")

// ─── Helpers ──────────────────────────────────────────────────────

func readPID() -> Int32? {
    guard let str = try? String(contentsOfFile: pidFile),
          let pid = Int32(str.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
    return pid
}

func isRunning(_ pid: Int32) -> Bool {
    kill(pid, 0) == 0
}

// ─── Commands ─────────────────────────────────────────────────────

func resolvedSelfPath() -> String {
    let arg0 = CommandLine.arguments[0]
    if arg0.hasPrefix("/") { return arg0 }

    // Search current process's PATH (avoids child-process PATH inheritance issues)
    let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
    for dir in pathEnv.split(separator: ":").map(String.init) {
        let candidate = dir + "/" + arg0
        if FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
    }
    return arg0
}

func cmdStart() {
    if let pid = readPID(), isRunning(pid) {
        print("Smack Attack is already running (PID \(pid)).")
        exit(0)
    }

    let selfPath = resolvedSelfPath()
    let task = Process()
    task.executableURL = URL(fileURLWithPath: selfPath)
    task.arguments = ["_run"]
    task.standardOutput = FileHandle.nullDevice
    task.standardError  = FileHandle.nullDevice

    do {
        try task.run()
    } catch {
        print("❌ Failed to start: \(error)")
        exit(1)
    }

    let pid = task.processIdentifier
    try? String(pid).write(toFile: pidFile, atomically: true, encoding: .utf8)
    print("✅ Smack Attack started (PID \(pid))")
    print("   Run 'smack stop' to stop it.")
}

func cmdStop() {
    guard let pid = readPID() else {
        print("Smack Attack is not running.")
        exit(0)
    }
    guard isRunning(pid) else {
        print("Smack Attack is not running. (cleaned up stale PID)")
        try? FileManager.default.removeItem(atPath: pidFile)
        exit(0)
    }
    kill(pid, SIGTERM)
    try? FileManager.default.removeItem(atPath: pidFile)
    print("✅ Smack Attack stopped.")
}

func cmdStatus() {
    guard let pid = readPID() else {
        print("Smack Attack is not running.")
        return
    }
    if isRunning(pid) {
        print("✅ Smack Attack is running (PID \(pid))")
    } else {
        print("Smack Attack is not running. (cleaned up stale PID)")
        try? FileManager.default.removeItem(atPath: pidFile)
    }
}

func cmdUninstall() {
    // Stop if running
    if let pid = readPID(), isRunning(pid) {
        kill(pid, SIGTERM)
        try? FileManager.default.removeItem(atPath: pidFile)
        print("Stopped running instance.")
    }

    let selfPath = resolvedSelfPath()

    do {
        try FileManager.default.removeItem(atPath: selfPath)
        print("✅ Smack Attack uninstalled.")
    } catch {
        print("❌ Failed to remove binary. Try: rm \(selfPath)")
    }
}

func cmdRun() {
    // Ensure sound file exists
    try? FileManager.default.createDirectory(atPath: soundDir, withIntermediateDirectories: true)
    if !FileManager.default.fileExists(atPath: soundPath) {
        let dl = Process()
        dl.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        dl.arguments = [
            "-L", "--silent", "--fail", "-o", soundPath,
            "https://upload.wikimedia.org/wikipedia/commons/transcoded/d/d9/Wilhelm_Scream.ogg/Wilhelm_Scream.ogg.mp3"
        ]
        try? dl.run()
        dl.waitUntilExit()
    }

    let detector = SmackDetector()
    try! detector.start()
    RunLoop.main.run()
}

func cmdHelp() {
    print("""
    Smack Attack — smack your MacBook, hear a scream.

    Usage:
      smack start      Start listening in the background
      smack stop       Stop the background process
      smack status     Check if it's running
      smack uninstall  Remove smack from your system
    """)
}

// ─── Detector ─────────────────────────────────────────────────────
final class SmackDetector: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var lastPlayTime = Date.distantPast

    func start() throws {
        let input  = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        try engine.start()
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            let s = channelData[i]
            sum += s * s
        }
        let rms = sqrt(sum / Float(frameLength))

        guard rms > threshold else { return }

        let now = Date()
        guard now.timeIntervalSince(lastPlayTime) > cooldown else { return }
        lastPlayTime = now

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        task.arguments = [soundPath]
        try? task.run()
    }
}

// ─── Dispatch ─────────────────────────────────────────────────────
let command = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "help"

switch command {
case "start":     cmdStart()
case "stop":      cmdStop()
case "status":    cmdStatus()
case "uninstall": cmdUninstall()
case "_run":      cmdRun()
default:          cmdHelp()
}
