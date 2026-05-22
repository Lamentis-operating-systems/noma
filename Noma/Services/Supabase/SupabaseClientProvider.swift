import Foundation
import Supabase

struct SupabaseConfiguration: Equatable {
    let projectURL: URL
    let publishableKey: String

    var isConfigured: Bool {
        let trimmedKey = publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedKey.isEmpty && trimmedKey != SupabaseClientProvider.publishableKeyPlaceholder
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
    static let projectRef = "ejulpxdohfnojevqntks"
    static let projectURL = URL(string: "https://ejulpxdohfnojevqntks.supabase.co")!
    static let publishableKeyInfoKey = "SUPABASE_PUBLISHABLE_KEY"
    static let publishableKeyPlaceholder = "YOUR_SUPABASE_PUBLISHABLE_KEY"
    static let bundledPublishableKey = "sb_publishable_eLKZGPZ-dvFYXK5F8VlNaQ_9oC6fOYt"

    static var currentConfiguration: SupabaseConfiguration {
        SupabaseConfiguration(
            projectURL: projectURL,
            publishableKey: configuredPublishableKey
        )
    }

    private static var configuredPublishableKey: String {
        guard let infoValue = Bundle.main.object(forInfoDictionaryKey: publishableKeyInfoKey) as? String else {
            return bundledPublishableKey
        }

        let trimmedInfoValue = infoValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedInfoValue.isEmpty ? bundledPublishableKey : trimmedInfoValue
    }

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
