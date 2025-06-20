import SwiftUI

struct SettingsView: View {
    var body: some View {
        // A simple placeholder view.
        VStack {
            Image(systemName: "gear")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            Text("This is a placeholder for the Settings screen.")
                .foregroundColor(.secondary)
        }
    }
}
