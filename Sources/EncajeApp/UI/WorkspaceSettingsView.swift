import EncajeCore
import SwiftUI

struct WorkspaceSettingsView: View {
  @ObservedObject var model: AppModel
  let granted: Bool
  @State private var name = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(spacing: 18) {
          LayoutIllustration().frame(width: 126, height: 84)
          VStack(alignment: .leading, spacing: 6) {
            Text(localized("A place for every window", "Un lugar para cada ventana"))
              .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(
              localized(
                "Arrange your apps once. Save the workspace and restore it whenever you need it.",
                "Ordena tus apps una vez. Guarda el espacio y recupéralo cuando lo necesites.")
            )
            .font(.callout).foregroundStyle(.secondary)
          }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
          .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        HStack {
          TextField(localized("Name this workspace", "Nombre de este espacio"), text: $name)
            .textFieldStyle(.roundedBorder).onSubmit(save)
            .accessibilityLabel(localized("Workspace name", "Nombre del espacio"))
          Button(action: save) {
            Label(localized("Save current", "Guardar actual"), systemImage: "plus")
          }
          .disabled(!canSave)
        }
        HStack {
          Text(localized("SAVED WORKSPACES", "ESPACIOS GUARDADOS"))
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
          Spacer()
          Text("\(model.layouts.count)").font(.caption).foregroundStyle(.secondary)
        }
        if model.layouts.isEmpty {
          VStack(spacing: 9) {
            Image(systemName: "rectangle.3.group").font(.system(size: 28)).foregroundStyle(.teal)
            Text(localized("Ready for your first workspace", "Listo para tu primer espacio")).font(
              .headline)
            Text(
              localized(
                "Try one for work, another for reading. Give your current arrangement a name above.",
                "Uno para trabajar, otro para leer. Dale un nombre arriba a tu distribución actual."
              )
            )
            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(
              maxWidth: 350)
          }.padding(28).frame(maxWidth: .infinity)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        }
        ForEach(model.layouts) { layout in
          HStack(spacing: 12) {
            Image(systemName: "rectangle.3.group.fill").font(.title3).foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 3) {
              Text(layout.name).font(.headline)
              Text(localized("\(layout.windows.count) windows", "\(layout.windows.count) ventanas"))
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(localized("Restore", "Restaurar")) { model.restoreLayout(layout) }.disabled(
              !granted)
            Button(role: .destructive) {
              model.layouts.removeAll { $0.id == layout.id }
            } label: {
              Image(systemName: "trash")
            }.buttonStyle(.borderless).accessibilityLabel(
              localized("Delete workspace", "Eliminar espacio") + " " + layout.name)
          }.padding(14).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        }
        Label(
          localized(
            "Restores windows that are still open. Apps and documents stay as they are.",
            "Restaura las ventanas que siguen abiertas. Conserva tus apps y documentos actuales."),
          systemImage: "info.circle"
        )
        .font(.caption).foregroundStyle(.secondary)
      }.padding(22)
    }
  }

  private var canSave: Bool {
    granted && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  private func save() {
    guard canSave else { return }
    model.saveLayout(name: name)
    name = ""
  }
}

struct LayoutIllustration: View {
  var body: some View {
    HStack(spacing: 5) {
      VStack(spacing: 5) {
        RoundedRectangle(cornerRadius: 5).fill(.teal.opacity(0.25))
        RoundedRectangle(cornerRadius: 5).fill(.teal.opacity(0.45))
      }
      RoundedRectangle(cornerRadius: 5).fill(.teal.gradient)
    }.padding(8).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
      .accessibilityHidden(true)
  }
}
