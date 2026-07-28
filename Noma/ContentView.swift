//
//  ContentView.swift
//  Noma
//
//  Created by Elias Papavlassopoulos on 15.05.26.
//

import SwiftUI

struct ContentView: View {
    @ViewBuilder
    var body: some View {
#if DEBUG
        if let uiTestConfiguration = NomaUITestLaunchConfiguration.current {
            NomaUITestRootView(configuration: uiTestConfiguration)
        } else {
            RootView()
        }
#else
        RootView()
#endif
    }
}

#Preview {
    @Previewable @State var authState = AuthStateManager(
        authClient: UnconfiguredAuthClient(error: SupabaseConfigurationError.missingPublishableKey)
    )

    ContentView()
        .environment(authState)
}
