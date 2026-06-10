import Foundation

/// Paywall A/B client (app target only). Fetches the server-assigned variant
/// and logs impressions. The variant is recomputed server-side at impression
/// AND purchase time, so nothing here is trusted for attribution — failures
/// just leave the user on the baked-in packs.
enum PaywallService {
    private struct VariantResponse: Decodable {
        let experiment: String
        let variant: String
        let productIDs: [String]
        let badgeProductID: String?
        let heroCopy: String?
    }

    /// Best-effort fetch of the assigned variant into the App Group cache.
    static func refresh() async {
        ReplyService.bootstrapAuthIfNeeded()
        guard let token = ReplyService.authToken else { return }
        var request = URLRequest(url: URL(string: Constants.backendURL + "/paywall")!)
        request.timeoutInterval = 8
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(VariantResponse.self, from: data) else { return }
        AppGroupService.shared.remotePaywallConfig = RemotePaywallConfig(
            experiment: decoded.experiment,
            variant: decoded.variant,
            productIDs: decoded.productIDs,
            badgeProductID: decoded.badgeProductID,
            heroCopy: decoded.heroCopy
        )
    }

    /// Fire-and-forget impression log. Body carries only the event type — the
    /// server attributes it to the variant it computes from the session.
    static func logImpression() {
        ReplyService.bootstrapAuthIfNeeded()
        guard let token = ReplyService.authToken else { return }
        var request = URLRequest(url: URL(string: Constants.backendURL + "/paywall/event")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["event": "impression"])
        URLSession.shared.dataTask(with: request).resume()
    }
}
