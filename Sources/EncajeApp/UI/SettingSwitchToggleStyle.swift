import SwiftUI

struct SettingSwitchToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    OutlinedSwitch(configuration: configuration)
  }

  private struct OutlinedSwitch: View {
    @Environment(\.colorScheme) private var colorScheme
    let configuration: Configuration

    var body: some View {
      Toggle(configuration).toggleStyle(.switch)
        .overlay(
          Capsule().strokeBorder(Color.primary.opacity(outlineOpacity), lineWidth: 1)
            .opacity(configuration.isOn ? 0 : 1)
            .allowsHitTesting(false))
    }

    private var outlineOpacity: Double { colorScheme == .dark ? 0.22 : 0.45 }
  }
}

extension ToggleStyle where Self == SettingSwitchToggleStyle {
  static var settingSwitch: SettingSwitchToggleStyle { SettingSwitchToggleStyle() }
}
