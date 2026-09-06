import EncajeCore
import SwiftUI

struct ZoneReference: Identifiable {
  let id: String
  let name: String
  let shortcut: String
  let zone: GridZone
  let color: Color
}

struct ZoneGridView: View {
  @Binding var zone: GridZone
  var references: [ZoneReference] = []
  var editingChanged: (Bool) -> Void = { _ in }
  @State private var dragging = false
  @GestureState private var gestureActive = false

  var body: some View {
    GeometryReader { proxy in
      let cellWidth = proxy.size.width / Double(zone.columns)
      let cellHeight = proxy.size.height / Double(zone.rows)
      ZStack(alignment: .topLeading) {
        Rectangle().fill(.quaternary.opacity(0.3))
        ForEach(references) { reference in
          ZoneReferenceShape(reference: reference, size: proxy.size)
        }
        Rectangle().fill(.teal.opacity(0.26))
          .frame(width: cellWidth * Double(zone.width), height: cellHeight * Double(zone.height))
          .overlay(Rectangle().strokeBorder(.teal, lineWidth: 2))
          .offset(x: cellWidth * Double(zone.x), y: cellHeight * Double(zone.y))
        Path { path in
          for column in 0...zone.columns {
            let x = Double(column) * cellWidth
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: proxy.size.height))
          }
          for row in 0...zone.rows {
            let y = Double(row) * cellHeight
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
          }
        }.stroke(.primary.opacity(0.12), lineWidth: 0.5)
        Text("\(zone.width) × \(zone.height)")
          .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
          .padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
          .position(
            x: cellWidth * (Double(zone.x) + Double(zone.width) / 2),
            y: cellHeight * (Double(zone.y) + Double(zone.height) / 2)
          )
          .allowsHitTesting(false)
      }.contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0).updating($gestureActive) { _, active, _ in active = true }
            .onChanged { value in
              if !dragging {
                editingChanged(true)
                dragging = true
              }
              let startX = min(zone.columns - 1, max(0, Int(value.startLocation.x / cellWidth)))
              let startY = min(zone.rows - 1, max(0, Int(value.startLocation.y / cellHeight)))
              let endX = min(zone.columns - 1, max(0, Int(value.location.x / cellWidth)))
              let endY = min(zone.rows - 1, max(0, Int(value.location.y / cellHeight)))
              var next = zone
              next.x = min(startX, endX)
              next.y = min(startY, endY)
              next.width = abs(endX - startX) + 1
              next.height = abs(endY - startY) + 1
              zone = next.normalized
            }.onEnded { _ in
              finishEditing()
            }
        )
        .onChange(of: gestureActive) { _, active in
          if !active { finishEditing() }
        }
        .onDisappear { finishEditing() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localized("Window zone preview", "Vista previa de la zona"))
        .accessibilityValue("\(zone.width) × \(zone.height), \(zone.x + 1), \(zone.y + 1)")
        .accessibilityHint(
          localized(
            "Use the size and position controls below to edit with the keyboard.",
            "Usa los controles de tamaño y posición inferiores para editar con el teclado."))
    }.aspectRatio(16 / 10, contentMode: .fit).padding(2)
  }
  private func finishEditing() {
    guard dragging else { return }
    editingChanged(false)
    dragging = false
  }

}

struct ZoneMiniature: View {
  let zone: GridZone?
  var selected = false

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 4).fill(.primary.opacity(0.05))
        if let zone = zone?.normalized {
          RoundedRectangle(cornerRadius: 2).fill(selected ? Color.teal : Color.teal.opacity(0.5))
            .frame(
              width: max(2, proxy.size.width * Double(zone.width) / Double(zone.columns) - 3),
              height: max(2, proxy.size.height * Double(zone.height) / Double(zone.rows) - 3)
            )
            .offset(
              x: proxy.size.width * Double(zone.x) / Double(zone.columns) + 1.5,
              y: proxy.size.height * Double(zone.y) / Double(zone.rows) + 1.5)
        } else {
          Image(systemName: "arrow.uturn.backward").font(.caption)
            .frame(maxWidth: .infinity, maxHeight: .infinity).foregroundStyle(.secondary)
        }
      }.overlay(RoundedRectangle(cornerRadius: 4).stroke(.primary.opacity(0.12)))
    }.accessibilityHidden(true)
  }
}

private struct ZoneReferenceShape: View {
  let reference: ZoneReference
  let size: CGSize

  var body: some View {
    let z = reference.zone.normalized
    Rectangle().fill(reference.color.opacity(0.06))
      .overlay {
        Rectangle().strokeBorder(
          reference.color.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
      }
      .frame(
        width: size.width * Double(z.width) / Double(z.columns),
        height: size.height * Double(z.height) / Double(z.rows)
      )
      .offset(
        x: size.width * Double(z.x) / Double(z.columns),
        y: size.height * Double(z.y) / Double(z.rows)
      )
      .allowsHitTesting(false)
  }
}
