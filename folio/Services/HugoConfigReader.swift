import Foundation

struct HugoConfig {
    var contentDir: String
    var staticDir: String
}

enum HugoConfigReader {
    /// Searches blogRoot for a Hugo config file and returns parsed values.
    /// Tries hugo.toml, hugo.yaml, hugo.json, config.toml, config.yaml, config.json in order.
    static func read(blogRoot: String) -> HugoConfig? {
        let candidates = ["hugo.toml", "hugo.yaml", "hugo.json",
                          "config.toml", "config.yaml", "config.json"]
        let fm = FileManager.default
        for filename in candidates {
            let path = blogRoot + "/" + filename
            guard fm.fileExists(atPath: path),
                  let data = fm.contents(atPath: path) else { continue }
            if filename.hasSuffix(".json") {
                return parseJSON(data)
            } else if filename.hasSuffix(".toml") {
                return parseTOML(String(data: data, encoding: .utf8) ?? "")
            } else {
                return parseYAML(String(data: data, encoding: .utf8) ?? "")
            }
        }
        return nil
    }

    private static func parseJSON(_ data: Data) -> HugoConfig? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let contentDir = obj["contentDir"] as? String ?? "content"
        let staticDir  = (obj["staticDir"] as? String)
            ?? (obj["staticDirs"] as? [String])?.first
            ?? "static"
        return HugoConfig(contentDir: contentDir, staticDir: staticDir)
    }

    private static func parseTOML(_ text: String) -> HugoConfig? {
        var contentDir = "content"
        var staticDir  = "static"
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let val = tomlValue(line: trimmed, key: "contentDir") { contentDir = val }
            if let val = tomlValue(line: trimmed, key: "staticDir")  { staticDir  = val }
        }
        return HugoConfig(contentDir: contentDir, staticDir: staticDir)
    }

    private static func parseYAML(_ text: String) -> HugoConfig? {
        var contentDir = "content"
        var staticDir  = "static"
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let val = yamlValue(line: trimmed, key: "contentDir") { contentDir = val }
            if let val = yamlValue(line: trimmed, key: "staticDir")  { staticDir  = val }
        }
        return HugoConfig(contentDir: contentDir, staticDir: staticDir)
    }

    /// Extracts value from a TOML line: `key = "value"` or `key = value`
    private static func tomlValue(line: String, key: String) -> String? {
        let prefix1 = key + " ="
        let prefix2 = key + "="
        var rest: String?
        if line.hasPrefix(prefix1) {
            rest = String(line.dropFirst(prefix1.count))
        } else if line.hasPrefix(prefix2) {
            rest = String(line.dropFirst(prefix2.count))
        }
        guard var r = rest else { return nil }
        r = r.trimmingCharacters(in: .whitespaces)
        if r.hasPrefix("\"") && r.hasSuffix("\"") {
            r = String(r.dropFirst().dropLast())
        }
        // Strip inline comment
        if let commentIdx = r.firstIndex(of: "#") {
            r = String(r[r.startIndex..<commentIdx]).trimmingCharacters(in: .whitespaces)
        }
        return r.isEmpty ? nil : r
    }

    /// Extracts value from a YAML line: `key: value` or `key: "value"`
    private static func yamlValue(line: String, key: String) -> String? {
        let prefix = key + ":"
        guard line.hasPrefix(prefix) else { return nil }
        var r = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        if r.hasPrefix("\"") && r.hasSuffix("\"") {
            r = String(r.dropFirst().dropLast())
        }
        // Strip inline comment
        if let commentIdx = r.firstIndex(of: "#") {
            r = String(r[r.startIndex..<commentIdx]).trimmingCharacters(in: .whitespaces)
        }
        return r.isEmpty ? nil : r
    }
}
