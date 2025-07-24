import SwiftUI
import MapKit

<<<<<<< HEAD
=======

>>>>>>> V1
struct LookAroundView: UIViewControllerRepresentable {
    var scene: MKLookAroundScene?

    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let viewController = MKLookAroundViewController()
        viewController.scene = scene
        // You can customize the view controller further if needed, e.g., badges, point of interest filter
        // viewController.showsRoadLabels = true
        // viewController.pointOfInterestFilter = .all
        return viewController
    }

    func updateUIViewController(_ uiViewController: MKLookAroundViewController, context: Context) {
        // Update the scene if it changes
        if uiViewController.scene != scene {
            uiViewController.scene = scene
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: MKLookAroundViewController, coordinator: ()) {
        // Clean up if necessary
        uiViewController.scene = nil
    }
}

<<<<<<< HEAD
// Optional: A simple placeholder if Look Around is not available or scene is nil,
=======
// Optional: A simple placeholder if Look Around is not available or scene is nil, 
// or to use while loading, though AsyncImage-like behavior is better handled in the parent view.

>>>>>>> V1
struct LookAroundContainerView: View {
    var scene: MKLookAroundScene?
    
    var body: some View {
        if let scene = scene {
            LookAroundView(scene: scene)
                .frame(height: 200) // Default frame, can be overridden
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            // Placeholder while loading or if scene is not available
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                ProgressView()
            }
            .frame(height: 200)
        }
    }
}
