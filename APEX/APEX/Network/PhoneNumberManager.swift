//
//  PhoneNumberManager.swift
//  APEX
//
//  Created by 조운경 on 10/17/25.
//

import Foundation
#if canImport(PhoneNumberKit)
import PhoneNumberKit
#endif

final class PhoneNumberManager {
    static let shared = PhoneNumberManager()

    private var region: String

    #if canImport(PhoneNumberKit)
    private let phoneNumberUtility: PhoneNumberUtility
    private var partialFormatter: PartialFormatter
    #endif

    private init(defaultRegion: String = Locale.current.regionCode ?? "KR") {
        self.region = defaultRegion
        #if canImport(PhoneNumberKit)
        self.phoneNumberUtility = PhoneNumberUtility()
        self.partialFormatter = PartialFormatter(
            utility: phoneNumberUtility,
            defaultRegion: defaultRegion,
            withPrefix: true
        )
        #endif
    }

    // MARK: - Exposed state
    var currentRegion: String { region }

    // MARK: - Configuration
    func setRegion(_ regionCode: String) {
        region = regionCode
        #if canImport(PhoneNumberKit)
        partialFormatter = PartialFormatter(
            utility: phoneNumberUtility,
            defaultRegion: regionCode,
            withPrefix: true
        )
        #endif
    }

    // MARK: - Parse / Validate
    #if canImport(PhoneNumberKit)
    func parse(_ raw: String, region overrideRegion: String? = nil) -> PhoneNumber? {
        let usedRegion = overrideRegion ?? region
        return try? phoneNumberUtility.parse(raw, withRegion: usedRegion, ignoreType: true)
    }
    #endif

    func isValid(_ raw: String, region overrideRegion: String? = nil) -> Bool {
        #if canImport(PhoneNumberKit)
        return parse(raw, region: overrideRegion) != nil
        #else
        // Very naive validation fallback: digits length >= 7
        let digits = raw.filter { $0.isNumber }
        return digits.count >= 7
        #endif
    }

    // MARK: - Format
    #if canImport(PhoneNumberKit)
    func e164(_ raw: String, region overrideRegion: String? = nil) -> String? {
        guard let number = parse(raw, region: overrideRegion) else { return nil }
        return phoneNumberUtility.format(number, toType: .e164)
    }

    func format(_ raw: String,
                style: PhoneNumberFormat = .international,
                region overrideRegion: String? = nil) -> String {
        guard let number = parse(raw, region: overrideRegion) else { return raw }
        return phoneNumberUtility.format(number, toType: style)
    }

    func format(number: PhoneNumber,
                style: PhoneNumberFormat = .international) -> String {
        return phoneNumberUtility.format(number, toType: style)
    }
    #endif

    // MARK: - As-you-type
    func partialFormat(_ raw: String) -> String {
        #if canImport(PhoneNumberKit)
        return partialFormatter.formatPartial(raw)
        #else
        return raw
        #endif
    }

    // Provide region-aware partial formatting without mutating the shared state
    func formatPartial(_ raw: String, region regionCode: String) -> String {
        #if canImport(PhoneNumberKit)
        if regionCode == region { return partialFormatter.formatPartial(raw) }
        let formatter = PartialFormatter(
            utility: phoneNumberUtility,
            defaultRegion: regionCode,
            withPrefix: true
        )
        return formatter.formatPartial(raw)
        #else
        return raw
        #endif
    }

    // MARK: - Metadata helpers
    func countryCode(for regionCode: String) -> UInt64? {
        #if canImport(PhoneNumberKit)
        return phoneNumberUtility.countryCode(for: regionCode)
        #else
        // Minimal known codes for preview fallback
        let map: [String: UInt64] = ["US": 1, "KR": 82, "JP": 81, "CN": 86, "GB": 44]
        return map[regionCode.uppercased()]
        #endif
    }

    func mainRegionCode(for countryCode: UInt64) -> String? {
        #if canImport(PhoneNumberKit)
        return phoneNumberUtility.mainCountry(forCode: countryCode)
        #else
        let map: [UInt64: String] = [1: "US", 82: "KR", 81: "JP", 86: "CN", 44: "GB"]
        return map[countryCode]
        #endif
    }

    // Returns a "+"-prefixed dialing code string (e.g., "+82") for a region, if available
    func dialCode(for regionCode: String) -> String? {
        guard let code = countryCode(for: regionCode) else { return nil }
        return "+\(code)"
    }

    // All ISO regions supported by PhoneNumberKit, sorted by localized region name
    func allRegions() -> [String] {
        let isoRegions = Locale.isoRegionCodes
        // Keep only regions recognized (have a known country calling code)
        let supported = isoRegions.filter { countryCode(for: $0) != nil }
        return supported.sorted { lhs, rhs in
            let lName = localizedRegionName(for: lhs)
            let rName = localizedRegionName(for: rhs)
            return lName.localizedCaseInsensitiveCompare(rName) == .orderedAscending
        }
    }

    // Localized human-readable name for a region code
    func localizedRegionName(for regionCode: String, locale: Locale = .current) -> String {
        return locale.localizedString(forRegionCode: regionCode) ?? regionCode
    }
}
