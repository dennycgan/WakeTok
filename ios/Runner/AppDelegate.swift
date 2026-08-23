import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Strong retain for preview request-id lifetime (Pigeon handlers also retain).
  private var photoLibraryService: PhotoLibraryService?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let photoLibraryService = PhotoLibraryService()
    self.photoLibraryService = photoLibraryService
    PhotoLibraryApiSetup.setUp(
      binaryMessenger: messenger,
      api: photoLibraryService
    )
    let playbackHost = PlaybackApiHost(binaryMessenger: messenger)
    PlaybackApiSetup.setUp(
      binaryMessenger: messenger,
      api: playbackHost
    )
    let livePhotoHost = LivePhotoApiHost(binaryMessenger: messenger)
    LivePhotoApiSetup.setUp(
      binaryMessenger: messenger,
      api: livePhotoHost
    )
    let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "WakeTokPlaybackSurface"
    )
    registrar?.register(
      PlaybackPlatformViewFactory(host: playbackHost),
      withId: PlaybackApiHost.viewType
    )
    let liveRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "WakeTokLivePhotoSurface"
    )
    liveRegistrar?.register(
      LivePhotoPlatformViewFactory(host: livePhotoHost),
      withId: LivePhotoApiHost.viewType
    )
  }
}
