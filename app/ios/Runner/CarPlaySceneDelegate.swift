import CarPlay
import UIKit

/// Scene delegate for the CarPlay scene (`CPTemplateApplicationSceneSessionRoleApplication`
/// in Info.plist). The phone scene stays the Flutter `SceneDelegate`.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  private var controller: CarPlayController?

  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                didConnect interfaceController: CPInterfaceController,
                                to window: CPWindow) {
    CarStore.shared.isCarPlayConnected = true
    let c = CarPlayController(interfaceController: interfaceController, window: window)
    controller = c
    c.start()
  }

  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                didDisconnect interfaceController: CPInterfaceController,
                                from window: CPWindow) {
    CarStore.shared.isCarPlayConnected = false
    controller?.stop()
    controller = nil
  }
}
