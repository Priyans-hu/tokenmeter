import SwiftUI

@main
struct TokenMeterApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            DashboardView(viewModel: viewModel)
                .frame(width: 340)
        } label: {
            Image(systemName: "chart.bar.fill")
                .symbolRenderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}
