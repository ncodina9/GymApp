import SwiftUI
import UIKit

/// Keeps the native left-edge pop gesture available when SwiftUI hides its
/// default navigation back button in favour of the bottom navigation controls.
struct InteractivePopGestureRestorer: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> PopGestureViewController {
    PopGestureViewController()
  }

  func updateUIViewController(_ uiViewController: PopGestureViewController, context: Context) {
    uiViewController.restoreInteractivePopGesture()
  }
}

final class PopGestureViewController: UIViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    restoreInteractivePopGesture()
  }

  func restoreInteractivePopGesture() {
    DispatchQueue.main.async { [weak self] in
      guard let navigationController = self?.navigationController,
            let gesture = navigationController.interactivePopGestureRecognizer
      else { return }

      gesture.isEnabled = true
      // SwiftUI disables this recognizer when navigationBarBackButtonHidden is
      // used. UIKit's default delegate already scopes it to the left edge.
      gesture.delegate = nil
    }
  }
}
