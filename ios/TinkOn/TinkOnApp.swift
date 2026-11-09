import SwiftUI

@main
struct TinkOnApp: App {
    @StateObject private var instrument = Instrument(
        padCapacity: UIDevice.current.userInterfaceIdiom == .pad ? Kit.slotCount : 8
    )
    var body: some Scene {
        WindowGroup { InstrumentView(instrument: instrument).persistentSystemOverlays(.hidden) }
    }
}
