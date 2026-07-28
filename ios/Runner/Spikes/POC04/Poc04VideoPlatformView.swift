import AVFoundation
import Flutter
import UIKit

/// UIView that keeps AVPlayerLayer sized to bounds (Fit via resizeAspect).
final class Poc04VideoContainerView: UIView {
  var playerLayer: AVPlayerLayer?

  override func layoutSubviews() {
    super.layoutSubviews()
    playerLayer?.frame = bounds
  }
}

final class Poc04VideoViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return Poc04VideoPlatformView(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      messenger: messenger
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

final class Poc04VideoPlatformView: NSObject, FlutterPlatformView {
  private let container = Poc04VideoContainerView()
  private let playerLayer = AVPlayerLayer()
  private var assetId: String?
  private var observer: NSObjectProtocol?

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    super.init()
    container.backgroundColor = .black
    playerLayer.videoGravity = .resizeAspect
    container.layer.addSublayer(playerLayer)
    container.playerLayer = playerLayer

    if let map = args as? [String: Any], let id = map["assetId"] as? String {
      assetId = id
      bindPlayer()
    }

    observer = NotificationCenter.default.addObserver(
      forName: .poc04PlayerPoolDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.bindPlayer()
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func view() -> UIView {
    return container
  }

  private func bindPlayer() {
    guard let assetId else { return }
    playerLayer.player = Poc04PlayerPool.shared.player(for: assetId)
    playerLayer.frame = container.bounds
  }
}
