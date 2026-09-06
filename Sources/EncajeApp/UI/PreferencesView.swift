import AppKit
import ServiceManagement
import SwiftUI

struct PreferencesView: View {
  @ObservedObject var model: AppModel
  @ObservedObject var permissions: PermissionCoordinator
  var showWelcome: () -> Void

  private var excludedIDs: [String] {
    Array(
      Set(
        model.exclusions.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map {
          $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })
    ).sorted()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        GroupBox {
          HStack(spacing: 12) {
            Image(systemName: permissions.granted ? "checkmark.shield.fill" : "hand.raised.fill")
              .font(.title2).foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 3) {
              Text(localized("Accessibility", "Accesibilidad")).font(.headline)
              Text(
                permissions.granted
                  ? localized(
                    "Accessibility access granted.",
                    "Permiso de Accesibilidad concedido.")
                  : localized(
                    "Allow Encaje to position your windows.",
                    "Permite que Encaje coloque tus ventanas.")
              )
              .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(
              permissions.granted
                ? localized("Review setup", "Ver bienvenida")
                : localized("Allow access", "Dar acceso"), action: showWelcome)
          }.padding(9)
        }
        GroupBox {
          VStack(spacing: 14) {
            HStack {
              Label(localized("Language", "Idioma"), systemImage: "globe")
              Spacer()
              Picker(localized("Language", "Idioma"), selection: $model.language) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                  Text(language.label).tag(language)
                }
              }.labelsHidden().fixedSize().frame(width: 150, alignment: .trailing)
            }
            Divider()
            HStack {
              Label(localized("Launch at login", "Abrir al iniciar sesión"), systemImage: "sunrise")
              Spacer()
              Toggle(
                localized("Launch at login", "Abrir al iniciar sesión"),
                isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })
              )
              .labelsHidden().toggleStyle(.switch)
            }.frame(maxWidth: .infinity)
            if model.loginApprovalNeeded {
              Button(localized("Approve in Login Items…", "Aprobar en Ítems de inicio…")) {
                SMAppService.openSystemSettingsLoginItems()
              }
            }
            Divider()
            HStack {
              Label(localized("Pause shortcuts", "Pausar atajos"), systemImage: "pause.circle")
              Spacer()
              Toggle(localized("Pause shortcuts", "Pausar atajos"), isOn: $model.paused)
                .labelsHidden().toggleStyle(.switch)
            }.frame(maxWidth: .infinity)
            Divider()
            HStack {
              Label(localized("Window spacing", "Separación entre ventanas"), systemImage: "space")
              Spacer()
              Text("\(Int(model.gap)) pt").font(.callout.monospacedDigit()).foregroundStyle(
                .secondary)
            }
            Slider(value: $model.gap, in: 0...32, step: 1)
              .accessibilityLabel(localized("Window spacing", "Separación entre ventanas"))
          }.padding(9)
        }
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(localized("Excluded apps", "Aplicaciones excluidas")).font(.headline)
              Text(
                localized(
                  "Keep normal typing and shortcuts in these apps.",
                  "Conserva la escritura y los atajos normales en estas apps.")
              )
              .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { model.addExcludedApp() }) {
              Label(localized("Add app", "Añadir app"), systemImage: "plus")
            }
          }
          if excludedIDs.isEmpty {
            Label(
              localized(
                "Encaje shortcuts are available in every app.",
                "Los atajos de Encaje están disponibles en todas las apps."),
              systemImage: "app.dashed"
            )
            .font(.callout).foregroundStyle(.secondary).padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
          }
          ForEach(excludedIDs, id: \.self) { bundleID in
            ExcludedAppRow(bundleID: bundleID) { model.removeExcludedApp(bundleID) }
          }
        }
        UpdateSettingsView()
        Text(
          localized(
            "Your window settings stay on your Mac.",
            "La configuración de tus ventanas se queda en tu Mac.")
        )
        .font(.caption).foregroundStyle(.tertiary)
      }.padding(22)
    }
  }
}

private struct ExcludedAppRow: View {
  let bundleID: String
  var remove: () -> Void

  private var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }

  var body: some View {
    HStack(spacing: 9) {
      if let appURL {
        Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path)).resizable().frame(
          width: 25, height: 25)
        Text(
          FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(
            of: ".app", with: ""))
      } else {
        Image(systemName: "app").frame(width: 25, height: 25)
        Text(bundleID)
      }
      Spacer()
      Button(action: remove) { Image(systemName: "minus.circle") }
        .buttonStyle(.borderless).accessibilityLabel(
          localized("Remove exclusion", "Eliminar exclusión") + " " + bundleID)
    }.padding(9).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
  }
}
