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

    func observeDays(onChange: @escaping ([DayLog]) -> Void) {
        let publisher: AnyPublisher<[DayLog], ClientError> =
            client.subscribe(to: "days:getDays", with: ["userId": userId], yielding: [DayLog].self)
        publisher
            .replaceError(with: [])
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

    func setMigraine(date: String, migraine: Migraine) async throws {
        let args: [String: ConvexEncodable?] = [
            "userId": userId, "date": date,
            "migraine": [
                "had": migraine.had, "severity": migraine.severity,
                "time": migraine.time, "notes": migraine.notes,
            ] as [String: ConvexEncodable?],
        ]
        try await client.mutation("days:setMigraine", with: args)
    }

    func removeMigraine(date: String) async throws {
        try await client.mutation("days:removeMigraine", with: ["userId": userId, "date": date])
    }

    func setSymptoms(date: String, symptoms: [String], loggedAt: String) async throws {
        let args: [String: ConvexEncodable?] = [
            "userId": userId, "date": date,
            "symptoms": symptoms as [ConvexEncodable?], "loggedAt": loggedAt,
        ]
        try await client.mutation("days:setSymptoms", with: args)
    }

    private nonisolated static func foodArgs(userId: String, date: String, food: FoodEntry) -> [String: ConvexEncodable?] {
        let triggers: [ConvexEncodable?] = food.triggers.map { t in
            [ "label": t.label, "level": t.level.rawValue, "reason": t.reason ?? "" ] as [String: ConvexEncodable?]
        }
        var foodDict: [String: ConvexEncodable?] = [
            "name": food.name, "time": food.time, "triggers": triggers, "note": food.note ?? "",
        ]
        if let imageId = food.imageId { foodDict["imageId"] = imageId }
        return ["userId": userId, "date": date, "food": foodDict]
    }

    func addFood(date: String, food: FoodEntry) async throws {
        try await client.mutation("days:addFood", with: ConvexService.foodArgs(userId: userId, date: date, food: food))
    }

    func removeFood(date: String, foodIndex: Int) async throws {
        try await client.mutation("days:removeFood",
            with: ["userId": userId, "date": date, "foodIndex": foodIndex])
    }

    func analyzeFood(description: String) async throws -> AnalyzedFood {
        let result: AnalyzedFood = try await client.action("ai:analyzeFood", with: ["description": description])
        return result
    }

    /// Upload image bytes to Convex storage, returning the storage id (or nil on failure).
    func uploadImage(_ data: Data) async throws -> String? {
        let uploadURL: String = try await client.mutation("files:generateUploadUrl", with: [:])
        guard let url = URL(string: uploadURL) else { return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (respData, _) = try await URLSession.shared.upload(for: req, from: data)
        struct UploadResp: Decodable { let storageId: String }
        return try? JSONDecoder().decode(UploadResp.self, from: respData).storageId
    }
}
