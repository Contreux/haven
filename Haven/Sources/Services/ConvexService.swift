import Foundation
import Combine
import ConvexMobile
import HavenCore

@MainActor
final class ConvexService: DayDataSource {
    // Verified dev deployment URL (P2). Public endpoint, not a secret.
    nonisolated static let deploymentURL = "https://cool-anteater-665.convex.cloud"

    private nonisolated(unsafe) let client: ConvexClient
    private let userId = DeviceIdentity.current
    private var cancellables: Set<AnyCancellable> = []

    nonisolated init() {
        client = ConvexClient(deploymentUrl: ConvexService.deploymentURL)
    }

    func observeDay(date: String, onChange: @escaping (DayLog?) -> Void) {
        let args: [String: ConvexEncodable?] = ["userId": userId, "date": date]
        let publisher: AnyPublisher<DayLog?, ClientError> =
            client.subscribe(to: "days:getDay", with: args, yielding: DayLog?.self)
        publisher
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { value in onChange(value) }
            .store(in: &cancellables)
    }

    func setFactors(date: String, factors: Factors, loggedAt: String) async throws {
        let args: [String: ConvexEncodable?] = [
            "userId": userId,
            "date": date,
            "factors": [
                "sleepHours": factors.sleepHours,
                "stress": factors.stress.rawValue,
                "hydration": factors.hydration.rawValue,
                "weatherSensitive": factors.weatherSensitive,
            ] as [String: ConvexEncodable?],
            "loggedAt": loggedAt,
        ]
        try await client.mutation("days:setFactors", with: args)
    }
}
