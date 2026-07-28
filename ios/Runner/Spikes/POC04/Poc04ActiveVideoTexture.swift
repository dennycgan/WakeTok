import AVFoundation
import CoreVideo
import Flutter
import Foundation
import UIKit

/// AVPlayer → CVPixelBuffer → FlutterTexture for POC-04 Conditional escape.
///
/// Ordering contract: callers must only expose [textureId] to Dart AFTER
/// [attach] returns (register has completed). Dart shows a black placeholder
/// until that id arrives, then setState → Texture(textureId).
final class Poc04ActiveVideoTexture: NSObject, FlutterTexture {
  private let registry: FlutterTextureRegistry
  private(set) var textureId: Int64 = -1
  private var videoOutput: AVPlayerItemVideoOutput?
  private var displayLink: CADisplayLink?
  private weak var player: AVPlayer?
  private var latestBuffer: CVPixelBuffer?
  private let bufferLock = NSLock()
  private var firstFrameDelivered = false
  var onFirstFrame: (() -> Void)?

  init(registry: FlutterTextureRegistry) {
    self.registry = registry
    super.init()
  }

  /// Registers with the engine and returns a valid textureId.
  /// Must complete register before returning (no async gap for Dart).
  @discardableResult
  func attach(player: AVPlayer) -> Int64 {
    detachOutputsOnly()
    self.player = player

    let attrs: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    ]
    let output = AVPlayerItemVideoOutput(pixelBufferAttributes: attrs)
    player.currentItem?.add(output)
    videoOutput = output

    // Register BEFORE returning id to Dart (ordering contract).
    if textureId < 0 {
      textureId = registry.register(self)
    }
    firstFrameDelivered = false
    startDisplayLink()
    return textureId
  }

  func detach() {
    stopDisplayLink()
    detachOutputsOnly()
    bufferLock.lock()
    latestBuffer = nil
    bufferLock.unlock()
    if textureId >= 0 {
      registry.unregisterTexture(textureId)
      textureId = -1
    }
    player = nil
    onFirstFrame = nil
  }

  private func detachOutputsOnly() {
    if let output = videoOutput, let item = player?.currentItem {
      item.remove(output)
    }
    videoOutput = nil
  }

  private func startDisplayLink() {
    stopDisplayLink()
    let link = CADisplayLink(target: self, selector: #selector(onDisplayLink(_:)))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  private func stopDisplayLink() {
    displayLink?.invalidate()
    displayLink = nil
  }

  @objc private func onDisplayLink(_ link: CADisplayLink) {
    guard let output = videoOutput else { return }
    let hostTime = CACurrentMediaTime()
    let itemTime = output.itemTime(forHostTime: hostTime)
    guard itemTime.isValid, itemTime.isNumeric else { return }
    guard output.hasNewPixelBuffer(forItemTime: itemTime) else { return }
    guard let buffer = output.copyPixelBuffer(
      forItemTime: itemTime,
      itemTimeForDisplay: nil
    ) else { return }

    bufferLock.lock()
    latestBuffer = buffer
    bufferLock.unlock()

    if textureId >= 0 {
      registry.textureFrameAvailable(textureId)
    }
    if !firstFrameDelivered {
      firstFrameDelivered = true
      onFirstFrame?()
    }
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    bufferLock.lock()
    defer { bufferLock.unlock() }
    guard let buffer = latestBuffer else { return nil }
    return Unmanaged.passRetained(buffer)
  }
}
