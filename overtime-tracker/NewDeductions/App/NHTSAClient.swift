import Foundation
import OvertimeCore

/// The app's only network call: a VIN sent to NHTSA vPIC. Nothing else is attached.
enum NHTSAClient {
    enum Failure: Error {
        case badURL
        case badResponse
    }

    static func decode(vin: String) async throws -> VPICDecoder.Decoded {
        let normalized = VINValidator.normalize(vin)
        guard let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/\(encoded)?format=json") else {
            throw Failure.badURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Failure.badResponse
        }
        return try VPICDecoder.decode(json: data)
    }
}
