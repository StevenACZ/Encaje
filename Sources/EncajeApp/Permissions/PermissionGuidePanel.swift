import AppKit
import SwiftUI

@MainActor
final class PermissionGuideState: ObservableObject {
  @Published var success = false
}

@MainActor
final class PermissionGuidePanel: NSPanel {
  let guideState = PermissionGuideState()

  init(close: @escaping () -> Void) {
    super.init(
      contentRect: CGRect(x: 0, y: 0, width: 360, height: 118),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    level = .floating
    hidesOnDeactivate = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    isReleasedWhenClosed = false
    let hosting = NSHostingView(rootView: PermissionGuideCard(state: guideState, close: close))
    hosting.sizingOptions = []
    contentView = hosting
  }

  override var canBecomeKey: Bool { false }
}

private struct PermissionGuideCard: View {
  @AppStorage("language", store: AppLanguage.defaults) private var language = "system"
  @ObservedObject var state: PermissionGuideState
  let close: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 14) {
      if state.success {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 44, weight: .medium))
          .foregroundStyle(.mint)
          .transition(.scale.combined(with: .opacity))
      } else {
        PermissionAppIcon()
          .frame(width: 58, height: 58)
          .accessibilityLabel(
            localized(
              "Drag Encaje to the Accessibility list", "Arrastra Encaje a la lista de Accesibilidad"
            ))
      }
      VStack(alignment: .leading, spacing: 5) {
        Text(
          state.success
            ? localized("Access granted", "Permiso concedido")
            : localized("Drag Encaje above", "Arrastra Encaje arriba")
        )
        .font(.system(size: 15, weight: .semibold))
        Text(
          state.success
            ? localized(
              "Accessibility access is enabled.", "El acceso a Accesibilidad está activado.")
            : localized(
              "Drop the icon in the list, then enable its switch.",
              "Suelta el icono en la lista y activa su interruptor.")
        )
        .font(.system(size: 12)).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
      Button(action: close) {
        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(localized("Dismiss guide", "Cerrar guía"))
    }
    .id(language)
    .padding(18)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.cyan.opacity(0.35), lineWidth: 1))
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: state.success)
  }
}
