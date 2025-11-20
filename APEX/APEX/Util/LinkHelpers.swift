import Foundation
import LinkPresentation

// Extracted link helpers for Chatting subviews

func urls(in text: String, limit: Int = 3) -> [URL] {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let textAsNSString = text as NSString
    let fullRange = NSRange(location: 0, length: textAsNSString.length)
    let matches = detector?.matches(in: text, options: [], range: fullRange) ?? []
    var seen = Set<String>()
    var extractedURLs: [URL] = []
    for match in matches {
        guard let range = Range(match.range, in: text) else { continue }
        let substring = String(text[range])
        let baseURL = match.url ?? normalizedURL(from: substring)
        guard let unwrapped = baseURL else { continue }
        let finalURL = normalizeURL(unwrapped)
        if seen.insert(finalURL.absoluteString).inserted {
            extractedURLs.append(finalURL)
            if extractedURLs.count >= limit { break }
        }
    }
    return extractedURLs
}

func normalizedURL(from raw: String) -> URL? {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = s.lowercased()
    if !(lower.hasPrefix("http://") || lower.hasPrefix("https://")) {
        s = "https://" + s
    }
    return URL(string: s)
}


