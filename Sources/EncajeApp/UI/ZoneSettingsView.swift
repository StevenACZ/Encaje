import AppKit
import EncajeCore
import SwiftUI

struct ZoneSettingsView: View {
  @ObservedObject var model: AppModel
  @State private var selectedID: String?
  @State private var confirmReset = false
  @State private var showReferences = false
  @State private var hiddenReferences: Set<String> = []

  private var selectedRule: WindowRule? {
    model.rules.first { $0.id == selectedID } ?? model.rules.first
  }

  var body: some View {
    HStack(spacing: 0) {
      VStack(spacing: 0) {
        HStack {
          Text(localized("YOUR ZONES", "TUS ZONAS")).font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Button {
            selectedID = model.addRule()
          } label: {
            Image(systemName: "plus").frame(width: 24, height: 24).contentShape(Rectangle())
          }
          .buttonStyle(.borderless).help(localized("Add a zone", "Añadir una zona"))
        }.padding(14)
        ScrollView {
          LazyVStack(spacing: 4) {
            ForEach(model.rules) { rule in
              ZoneRuleRow(rule: rule, selected: selectedRule?.id == rule.id) {
                selectedID = rule.id
              }
            }
          }.padding(.horizontal, 6)
        }
        Divider()
        Button {
          confirmReset = true
        } label: {
          Text(localized("Restore defaults", "Restaurar originales"))
            .frame(maxWidth: .infinity).padding(12).contentShape(Rectangle())
        }.font(.caption).buttonStyle(.borderless)
      }.frame(width: 202)
      Divider()
      if let rule = selectedRule {
        ZoneRuleEditor(
          model: model, rule: rule, showReferences: $showReferences,
          hiddenReferences: $hiddenReferences
        ) {
          model.removeRule(id: rule.id)
          selectedID = model.rules.first?.id
        }.id(rule.id)
      } else {
        ContentUnavailableView {
          Label(
            localized("Create your first zone", "Crea tu primera zona"),
            systemImage: "rectangle.dashed")
        } actions: {
          Button(localized("Add zone", "Añadir zona")) { selectedID = model.addRule() }
        }
      }
    }
    .onChange(of: model.zoneHistoryRevision) { _, _ in
      if let id = model.zoneHistorySelection { selectedID = id }
    }
    .confirmationDialog(
      localized(
        "Restore the original zones and shortcuts?", "¿Restaurar las zonas y atajos originales?"),
      isPresented: $confirmReset, titleVisibility: .visible
    ) {
      Button(localized("Restore defaults", "Restaurar originales"), role: .destructive) {
        model.resetRules()
        selectedID = model.rules.first?.id
      }
    }
  }

}

private struct ZoneRuleRow: View {
  let rule: WindowRule
  let selected: Bool
  var select: () -> Void

  var body: some View {
    Button(action: select) {
      HStack(spacing: 8) {
        ZoneMiniature(zone: rule.zone ?? GridZone.defaultZone(for: rule.action), selected: selected)
          .frame(width: 37, height: 26)
        Text(rule.title.isEmpty ? rule.action.label : rule.title)
          .font(.system(size: 12, weight: .medium)).lineLimit(1)
        Spacer(minLength: 2)
        if rule.keyCode != nil {
          Text(ShortcutPresentation.label(keyCode: rule.keyCode, modifiers: rule.modifiers)).font(
            .system(size: 10, weight: .semibold, design: .monospaced)
          )
          .foregroundStyle(.secondary)
        }
      }.padding(7).frame(maxWidth: .infinity, alignment: .leading)
        .background(
          selected ? Color.teal.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 7)
        )
        .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct ZoneRuleEditor: View {
  @ObservedObject var model: AppModel
  let rule: WindowRule
  @State private var dragInitial: GridZone?
  @State private var isDragging = false
  @Binding var showReferences: Bool
  @Binding var hiddenReferences: Set<String>
  var remove: () -> Void

  private var zone: GridZone? { rule.zone ?? GridZone.defaultZone(for: rule.action) }
  private var zoneBinding: Binding<GridZone> {
    Binding(
      get: { zone ?? GridZone(columns: 24, rows: 24, x: 0, y: 0, width: 24, height: 24) },
      set: { next in change { $0.zone = next.normalized } })
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 16) {
          TextField(
            rule.action.label,
            text: Binding(get: { rule.title }, set: { value in change { $0.title = value } })
          )
          .textFieldStyle(.plain).font(.system(size: 18, weight: .semibold, design: .rounded))
          .accessibilityLabel(localized("Zone name", "Nombre de la zona"))
          Spacer(minLength: 0)
          ShortcutRecorder(keyCode: rule.keyCode, modifiers: rule.modifiers) { keyCode, modifiers in
            change {
              $0.keyCode = keyCode
              $0.modifiers = modifiers
            }
          }.frame(width: 144, height: 28)

          Button(role: .destructive, action: remove) {
            Image(systemName: "trash").frame(width: 28, height: 30).contentShape(Rectangle())
          }
          .buttonStyle(.borderless).help(localized("Delete zone", "Eliminar zona"))
        }
        if let zone {
          HStack {
            Button {
              model.undoZoneEdit()
            } label: {
              Label(localized("Undo", "Deshacer"), systemImage: "arrow.uturn.backward")
            }.disabled(model.isEditingZone || !model.zoneHistory.canUndo).help("⌘ Z")
            Button {
              model.redoZoneEdit()
            } label: {
              Image(systemName: "arrow.uturn.forward")
            }.disabled(model.isEditingZone || !model.zoneHistory.canRedo)
              .accessibilityLabel(localized("Redo", "Rehacer")).help("⇧ ⌘ Z")
            Spacer()
            Toggle(isOn: $showReferences) {
              Label(localized("Other zones", "Otras zonas"), systemImage: "square.3.layers.3d")
            }.toggleStyle(.button)
          }.buttonStyle(.borderless).font(.caption)
          if showReferences {
            referencePicker
          }
          ZoneGridView(
            zone: zoneBinding,
            references: showReferences
              ? references.filter { !hiddenReferences.contains($0.id) } : [],
            editingChanged: { editing in
              if editing {
                NSApplication.shared.keyWindow?.makeFirstResponder(nil)
                dragInitial = rule.zone
                isDragging = true
                model.isEditingZone = true
              } else {
                model.recordZoneEdit(id: rule.id, before: dragInitial)
                isDragging = false
                model.isEditingZone = false
                dragInitial = nil
              }
            }
          ).frame(height: 218).frame(maxWidth: .infinity)
          HStack {
            Label(
              localized("Drag to choose cells", "Arrastra para elegir celdas"),
              systemImage: "cursorarrow")
            Spacer()
            Text(
              "\(Int((Double(zone.width) / Double(zone.columns) * 100).rounded()))% × \(Int((Double(zone.height) / Double(zone.rows) * 100).rounded()))%"
            )
            .monospacedDigit()
          }.font(.caption).foregroundStyle(.secondary)
          DisclosureGroup(localized("Fine tune", "Ajuste preciso")) {
            VStack(spacing: 12) {
              Grid(horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                  control(
                    localized("Width", "Ancho"), keyPath: \.width,
                    range: 1...(zone.columns - zone.x))
                  control(
                    localized("Height", "Alto"), keyPath: \.height, range: 1...(zone.rows - zone.y))
                }
                GridRow {
                  control(
                    localized("Column", "Columna"), keyPath: \.x,
                    range: 1...(zone.columns - zone.width + 1), offset: 1)
                  control(
                    localized("Row", "Fila"), keyPath: \.y,
                    range: 1...(zone.rows - zone.height + 1), offset: 1)
                }
                GridRow {
                  control(localized("Columns", "Columnas"), keyPath: \.columns, range: 1...64)
                  control(localized("Rows", "Filas"), keyPath: \.rows, range: 1...64)
                }
              }
            }.padding(.top, 10)
          }.font(.caption).foregroundStyle(.secondary)

        }
        Divider()
        Picker(
          localized("Movement", "Movimiento"),
          selection: Binding(
            get: {
              [.left, .right, .up, .down, .undo, .restore].contains(rule.action)
                ? rule.action : .center
            },
            set: { action in
              change {
                if $0.title.isEmpty { $0.title = $0.action.label }
                $0.action = action
                if [.undo, .restore].contains(action) {
                  $0.zone = nil
                } else {
                  $0.zone =
                    $0.zone ?? GridZone.defaultZone(for: action)
                    ?? GridZone(x: 6, y: 6, width: 12, height: 12)
                }
              }
            })
        ) {
          ForEach(
            [WindowAction.center, .left, .right, .up, .down, .undo, .restore], id: \.rawValue
          ) { action in
            Text(
              action == .center
                ? localized("Stay on this display", "Mantener en esta pantalla") : action.label
            ).tag(action)
          }
        }

        Text(movementHint).font(.caption).foregroundStyle(.secondary)
        Text(
          rule.modifiers.isEmpty
            ? localized(
              "A shortcut without modifiers replaces normal typing. Add ⌘, ⌥, ⌃ or ⇧ to avoid this.",
              "Un atajo sin modificadores reemplaza la escritura normal. Añade ⌘, ⌥, ⌃ o ⇧ para evitarlo."
            )
            : localized(
              "Shortcuts replace the same keys in other apps. You can pause Encaje anytime.",
              "Los atajos reemplazan esas teclas en otras apps. Puedes pausar Encaje cuando quieras."
            )
        )
        .font(.system(size: 10)).foregroundStyle(.tertiary)
      }.padding(18)
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var references: [ZoneReference] {
    model.rules.filter { $0.id != rule.id }.enumerated().compactMap { index, candidate in
      guard let zone = candidate.zone?.normalized,
        zone.width < zone.columns || zone.height < zone.rows
      else { return nil }
      return ZoneReference(
        id: candidate.id,
        name: candidate.title.isEmpty ? candidate.action.label : candidate.title,
        shortcut: ShortcutPresentation.label(
          keyCode: candidate.keyCode, modifiers: candidate.modifiers),
        zone: zone, color: [.orange, .purple, .blue, .pink][index % 4])
    }
  }

  private var referencePicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(localized("Choose zones to compare", "Elige las zonas que quieres comparar"))
        .font(.caption).foregroundStyle(.secondary)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], alignment: .leading, spacing: 6) {
        ForEach(references) { reference in
          Toggle(
            isOn: Binding(
              get: { !hiddenReferences.contains(reference.id) },
              set: { visible in
                if visible {
                  hiddenReferences.remove(reference.id)
                } else {
                  hiddenReferences.insert(reference.id)
                }
              }
            )
          ) {
            HStack(spacing: 4) {
              Circle().fill(reference.color).frame(width: 6, height: 6)
              Text(reference.name).lineLimit(1)
            }
          }.font(.caption).help(reference.name + " · " + reference.shortcut)
        }
      }
    }.padding(10).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
  }

  private var movementHint: String {
    switch rule.action {
    case .left, .right, .up, .down:
      localized(
        "Repeat this shortcut to continue to the neighboring display.",
        "Repite este atajo para continuar a la pantalla vecina.")
    case .undo, .restore:
      localized(
        "Bring the window back to its previous position.",
        "Recupera la posición anterior de la ventana.")
    default:
      localized("Uses this zone on the current display.", "Usa esta zona en la pantalla actual.")
    }
  }

  private func control(
    _ label: String, keyPath: WritableKeyPath<GridZone, Int>, range: ClosedRange<Int>,
    offset: Int = 0
  ) -> some View {
    HStack(spacing: 5) {
      Text(label).font(.caption).foregroundStyle(.secondary)
      Spacer(minLength: 0)
      Stepper(
        value: Binding(
          get: { zoneBinding.wrappedValue[keyPath: keyPath] + offset },
          set: { value in
            NSApplication.shared.keyWindow?.makeFirstResponder(nil)
            var next = zoneBinding.wrappedValue
            next[keyPath: keyPath] = value - offset
            zoneBinding.wrappedValue = next
          }), in: range
      ) {
        Text("\(zoneBinding.wrappedValue[keyPath: keyPath] + offset)")
          .font(.system(.callout, design: .monospaced)).frame(minWidth: 22, alignment: .trailing)
      }.fixedSize().accessibilityLabel(label)
    }.frame(maxWidth: .infinity)
  }

  private func change(_ mutation: (inout WindowRule) -> Void) {
    var next = rule
    mutation(&next)
    model.updateRule(next, recordHistory: !isDragging)
  }
}
