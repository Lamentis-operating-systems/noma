import Foundation
import Supabase

struct SupabaseConfiguration: Equatable {
    let projectURL: URL
    let publishableKey: String

    var isConfigured: Bool {
        let trimmedKey = publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedKey.isEmpty
    }
}

enum SupabaseConfigurationError: LocalizedError {
    case missingPublishableKey

    var errorDescription: String? {
        switch self {
        case .missingPublishableKey:
            "Supabase publishable key is not configured."
        }
    }
}

enum SupabaseClientProvider {
    static let projectURL = URL(string: "https://ogajkrmbznzpwjxhaxev.supabase.co")!
    static let publishableKey = "sb_publishable_E3HMXc_UUrRSPW_foteV_w_oPMgzB5X"

    static let currentConfiguration = SupabaseConfiguration(
        projectURL: projectURL,
        publishableKey: publishableKey
    )

    static var clientOptions: SupabaseClientOptions {
        SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
    }

    static var emitsLocalSessionAsInitialSession: Bool {
        clientOptions.auth.emitLocalSessionAsInitialSession
    }

    static func edgeFunctionURL(
        named functionName: String,
        configuration: SupabaseConfiguration = currentConfiguration
    ) -> URL {
        configuration.projectURL
            .appending(path: "functions")
            .appending(path: "v1")
            .appending(path: functionName)
    }

    static func makeClient(configuration: SupabaseConfiguration = currentConfiguration) throws -> SupabaseClient {
        guard configuration.isConfigured else {
            throw SupabaseConfigurationError.missingPublishableKey
        }

        return SupabaseClient(
            supabaseURL: configuration.projectURL,
            supabaseKey: configuration.publishableKey,
            options: clientOptions
        )
    }

    @MainActor
    static func makeAuthClient() -> any AuthClient {
        do {
            let configuration = currentConfiguration
            return SupabaseAuthClient(
                client: try makeClient(configuration: configuration),
                configuration: configuration
            )
        } catch {
            return UnconfiguredAuthClient(error: error)
        }
    }
}
