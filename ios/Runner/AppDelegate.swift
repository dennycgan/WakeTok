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
    PhotoLibraryApiSetup.setUp(
      binaryMessenger: messenger,
      api: PhotoLibraryService()
    )
    let playbackHost = PlaybackApiHost()
    PlaybackApiSetup.setUp(
      binaryMessenger: messenger,
      api: playbackHost
    )
    let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "WakeTokPlaybackSurface"
    )
    registrar?.register(
      PlaybackPlatformViewFactory(host: playbackHost),
      withId: PlaybackApiHost.viewType
    )
  }
}
