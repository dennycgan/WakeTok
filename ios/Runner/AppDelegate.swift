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
    let textures = engineBridge.applicationRegistrar.textures()
    Poc04PlayerPool.shared.configure(textureRegistry: textures)
    // Default to Texture surface (Conditional escape); Dart can toggle back to PV.
    Poc04PlayerPool.shared.setUseTextureSurface(true)

    Poc04PhotoLibraryApiSetup.setUp(
      binaryMessenger: messenger,
      api: Poc04PhotoLibraryHost()
    )
    Poc04MediaBridgeApiSetup.setUp(
      binaryMessenger: messenger,
      api: Poc04MediaBridgeHost()
    )
    Poc03PlaybackApiSetup.setUp(
      binaryMessenger: messenger,
      api: Poc03PlaybackHost()
    )
    Poc09ExportApiSetup.setUp(
      binaryMessenger: messenger,
      api: Poc09ExportHost()
    )
    let videoFactory = Poc04VideoViewFactory(messenger: messenger)
    engineBridge.applicationRegistrar.register(
      videoFactory,
      withId: "poc04_av_player"
    )
  }
}
