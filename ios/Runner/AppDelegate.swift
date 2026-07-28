import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    Poc04PhotoLibraryApiSetup.setUp(
      binaryMessenger: messenger,
      api: Poc04PhotoLibraryHost()
    )
    Poc04MediaBridgeApiSetup.setUp(
      binaryMessenger: messenger,
      api: Poc04MediaBridgeHost()
    )
    let videoFactory = Poc04VideoViewFactory(messenger: messenger)
    engineBridge.applicationRegistrar.register(
      videoFactory,
      withId: "poc04_av_player"
    )
  }
}
