// TransitModel.swift
// Fetches real-time train arrival data from Hong Kong MTR open data API.
// HKMTR Real-time API Docs: https://data.gov.hk/en-data/dataset/mtr-data2-nexttrain-data
// HKLRT Real-time API Docs: https://data.gov.hk/tc-data/dataset/mtr-lrnt_data-light-rail-nexttrain-data

import Foundation
import Combine
import SwiftUI

// MARK: - DTOs returned by the MTR real-time endpoint
struct HK_MTRResponse: Decodable {
    let systemTime: String
    let data: [String: [String: [String: [TrainETA]]]]

    enum CodingKeys: String, CodingKey {
        case systemTime = "system_time"
        case data
    }
}

struct TrainETA: Decodable, Identifiable {
    // Use a synthetic UUID so SwiftUI Lists et al. can diff the rows.
    var id: UUID { UUID() }

    let dest: String   // Destination station code (e.g. "TUC")
    let plat: String   // Platform number as string
    let time: String   // Minutes until arrival or "ARR" / "DEP"
}

// MARK: - Networking helper
enum MTRAPI {
    enum APIError: Error { case badURL }

    /// Fetch schedule for a given line/station/direction.
    /// - Parameters:
    ///   - line: Three-letter line code (e.g. "TCL").
    ///   - station: Three-letter station code (e.g. "OLY").
    ///   - direction: "UP" or "DOWN".
    static func fetchSchedule(line: String = "TCL", station: String = "OLY", direction: String = "UP") async throws -> [TrainETA] {
        guard let url = URL(string: "https://rt.data.gov.hk/v1/transport/mtr/getSchedule.php?line=\(line)&sta=\(station)") else {
            throw APIError.badURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(MTRResponse.self, from: data)
        return decoded.data[station]?[line]?[direction] ?? []
    }
}

// MARK: - ObservableObject for SwiftUI views
@MainActor
final class TransitModel: ObservableObject {
    // Selected line and station codes; updating either automatically refreshes data.
    @Published var lineCode: String = "TCL" { didSet { refresh() } }
    @Published var stationCode: String = "OLY" { didSet { refresh() } }

    @Published var upArrivals: [TrainETA] = []
    @Published var downArrivals: [TrainETA] = []

    /// Manually refreshes arrivals using the current `lineCode` and `stationCode`.
    /// Call after changing `lineCode` or `stationCode`.
    func refresh() {
        Task {
            do {
                let up = try await MTRAPI.fetchSchedule(line: lineCode, station: stationCode, direction: "UP")
                let down = try await MTRAPI.fetchSchedule(line: lineCode, station: stationCode, direction: "DOWN")
                // Limit to next four arrivals each direction.
                upArrivals = Array(up.prefix(4))
                downArrivals = Array(down.prefix(4))
            } catch {
                print("MTR ETA fetch failed:", error)
            }
        }
    }
}

// MARK: - Preview helper
#if DEBUG
struct TransitModel_Previews: PreviewProvider {
    static var previews: some View {
        let model = TransitModel()
        VStack(spacing: 16) {
            HStack {
                TextField("Line", text: $model.lineCode).textFieldStyle(.roundedBorder)
                TextField("Station", text: $model.stationCode).textFieldStyle(.roundedBorder)
                Button("Refresh") { model.refresh() }
            }.padding()

            List {
                Section("Up") {
                    ForEach(model.upArrivals) { Text("→ \($0.dest)  \($0.time) min") }
                }
                Section("Down") {
                    ForEach(model.downArrivals) { Text("→ \($0.dest)  \($0.time) min") }
                }
            }
        }
        .task { model.refresh() }
        .frame(maxHeight: .infinity)
    }
}
#endif

