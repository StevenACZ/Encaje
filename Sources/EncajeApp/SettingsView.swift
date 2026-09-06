import AppKit
import EncajeCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel
  @ObservedObject var permissions: PermissionCoordinator
  @State private var section = 0
  var showWelcome: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      sidebar
      Divider()
      VStack(spacing: 0) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(sectionTitle).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(sectionSubtitle).font(.callout).foregroundStyle(.secondary)
          }
          Spacer()
        }.padding(22).padding(.top, 12)
        Divider()
        Group {
          switch section {
          case 0: ZoneSettingsView(model: model)
          case 1: WorkspaceSettingsView(model: model, granted: permissions.granted)
          default:
            PreferencesView(model: model, permissions: permissions, showWelcome: showWelcome)
          }
        }.id(model.language).frame(maxWidth: .infinity, maxHeight: .infinity)
        if let message = model.message {
          HStack {
            Image(systemName: "info.circle").foregroundStyle(.teal)
            Text(message).font(.callout).textSelection(.enabled)
            Spacer()
            Button {
              model.message = nil
            } label: {
              Image(systemName: "xmark").frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(localized("Dismiss", "Cerrar"))
          }.padding(12).background(.quaternary.opacity(0.5))
        }
      }
    }.frame(width: 880, height: 660).ignoresSafeArea(.container, edges: .top).tint(.teal)
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(nsImage: AppArtwork.icon).resizable()
        .frame(width: 44, height: 44).padding(.bottom, 6)
      Text("Encaje").font(.system(size: 21, weight: .bold, design: .rounded))
      Text(localized("Your space, your way.", "Tu espacio, a tu manera."))
        .font(.caption).foregroundStyle(.secondary).padding(.bottom, 23)
      navigation(localized("Zones", "Zonas"), symbol: "rectangle.split.2x2", index: 0)
      navigation(localized("Workspaces", "Espacios"), symbol: "rectangle.3.group", index: 1)
      navigation(localized("Preferences", "Preferencias"), symbol: "slider.horizontal.3", index: 2)
      Spacer()
      Button {
        model.paused.toggle()
      } label: {
        Label(
          model.paused ? localized("Resume", "Reanudar") : localized("Pause", "Pausar"),
          systemImage: model.paused ? "play.fill" : "pause.fill"
        ).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 10).contentShape(Rectangle())
      }.buttonStyle(.plain)
      Label(
        model.paused
          ? localized("Paused", "En pausa")
          : model.ready ? localized("Ready", "Listo") : localized("Setup needed", "Falta acceso"),
        systemImage: model.ready && !model.paused ? "checkmark.circle.fill" : "circle"
      ).font(.caption).foregroundStyle(model.ready && !model.paused ? .teal : .secondary)
    }.padding(16).padding(.top, 28).frame(width: 152).frame(maxHeight: .infinity)
      .background(.quaternary.opacity(0.22))
  }

  private func navigation(_ title: String, symbol: String, index: Int) -> some View {
    Button {
      section = index
    } label: {
      Label(title, systemImage: symbol).font(.system(size: 12, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10).padding(
          .horizontal, 9
        )
        .background(
          section == index ? Color.teal.opacity(0.16) : .clear,
          in: RoundedRectangle(cornerRadius: 8)
        )
        .foregroundStyle(section == index ? Color.teal : Color.primary)
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }.buttonStyle(.plain).accessibilityAddTraits(section == index ? .isSelected : [])
  }

  private var sectionTitle: String {
    switch section {
    case 0: localized("Make room for your workflow", "Dale espacio a tu forma de trabajar")
    case 1: localized("Your favorite arrangements", "Tus espacios favoritos")
    default: localized("Make Encaje yours", "Encaje, a tu gusto")
    }
  }

  private var sectionSubtitle: String {
    switch section {
    case 0:
      localized(
        "Pick a shortcut. Draw exactly where its window belongs.",
        "Elige un atajo. Dibuja el espacio que ocupará su ventana.")
    case 1:
      localized(
        "Save your open windows and bring them back into place.",
        "Guarda tus ventanas abiertas y recupera su posición.")
    default:
      localized(
        "A few small details for a better everyday workspace.",
        "Pequeños detalles para trabajar más a gusto.")
    }
  }
}
