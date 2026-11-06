import Combine
import Foundation

struct AvailableUpdate: Equatable {
    let version: String
    let releaseURL: URL
}

enum UpdateCheckerError: LocalizedError {
    case invalidResponse
    case network(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an unexpected response."
        case let .network(error):
            return "Could not reach GitHub: \(error.localizedDescription)"
        case let .decoding(error):
            return "Could not read the GitHub release: \(error.localizedDescription)"
        }
    }
}

struct SemanticVersion: Comparable {
    private let components: [Int]

    init?(_ string: String) {
        let cleaned = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

        let parts = cleaned.split(separator: ".")
        guard !parts.isEmpty else { return nil }

        var values: [Int] = []
        for part in parts {
            let digits = part.prefix { $0.isNumber }
            guard !digits.isEmpty, let value = Int(String(digits)) else { return nil }
            values.append(value)
        }

        components = values
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)

        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0

            if left != right {
                return left < right
            }
        }

        return false
    }
}

final class UpdateChecker: ObservableObject {
    @Published private(set) var availableUpdate: AvailableUpdate?
    @Published private(set) var isChecking = false
    @Published private(set) var errorMessage: String?

    private let settings: AppSettings
    private var timer: Timer?

    private static let releaseURL = URL(
        string: "https://api.github.com/repos/alouiadel/lidward/releases/latest"
    )!

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        checkIfDue()

        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            self?.checkIfDue()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func checkIfDue() {
        guard settings.automaticallyCheckForUpdates else { return }

        if let lastCheck = settings.lastUpdateCheck,
           Date().timeIntervalSince(lastCheck) < 86_400 {
            return
        }

        check(force: false)
    }

    func check(force: Bool, completion: ((Error?) -> Void)? = nil) {
        guard !isChecking else { return }
        if !force && !settings.automaticallyCheckForUpdates { return }

        isChecking = true
        errorMessage = nil
        postStatus()

        var request = URLRequest(url: Self.releaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Lidward", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                self.finish(.network(error), completion: completion)
                return
            }

            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data else {
                self.finish(.invalidResponse, completion: completion)
                return
            }

            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                DispatchQueue.main.async {
                    self.handle(release, completion: completion)
                }
            } catch {
                self.finish(.decoding(error), completion: completion)
            }
        }.resume()
    }

    private func handle(_ release: GitHubRelease, completion: ((Error?) -> Void)?) {
        let remoteString = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let currentString = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0"

        guard let remote = SemanticVersion(remoteString),
              let current = SemanticVersion(currentString) else {
            finish(.invalidResponse, completion: completion)
            return
        }

        if remote > current, let url = URL(string: release.htmlURL) {
            availableUpdate = AvailableUpdate(version: remoteString, releaseURL: url)
        } else {
            availableUpdate = nil
        }

        finish(nil, completion: completion)
    }

    private func finish(_ error: UpdateCheckerError?, completion: ((Error?) -> Void)?) {
        DispatchQueue.main.async {
            self.isChecking = false
            self.settings.lastUpdateCheck = Date()

            if let error {
                self.errorMessage = error.localizedDescription
            }

            self.postStatus()
            completion?(error)
        }
    }

    private func postStatus() {
        NotificationCenter.default.post(name: .lidwardUpdateStatusDidChange, object: self)
    }

    deinit {
        timer?.invalidate()
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
    }
}
