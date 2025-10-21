//
//  PhoneService.swift
//  APEX
//
//  Created by 조운경 on 10/15/25.
//

import Foundation
import PhoneNumberKit

final class PhoneService {
    static let shared = PhoneService()

    private let utility: PhoneNumberUtility
    private let partial: PartialFormatter
    private let defaultRegion: String

    private init(defaultRegion: String = Locale.current.regionCode ?? "KR") {
        self.defaultRegion = defaultRegion
        self.utility = PhoneNumberUtility()
        self.partial = PartialFormatter(utility: utility, defaultRegion: defaultRegion, withPrefix: false)
    }

    func isValid(_ text: String) -> Bool {
        (try? utility.parse(text, withRegion: defaultRegion)) != nil
    }

    func isValid(_ text: String, region: String) -> Bool {
        (try? utility.parse(text, withRegion: region)) != nil
    }

    func formatPartial(_ text: String) -> String {
        partial.formatPartial(text)
    }

    func formatPartial(_ text: String, region: String) -> String {
        let regionalFormatter = PartialFormatter(utility: utility, defaultRegion: region, withPrefix: false)
        return regionalFormatter.formatPartial(text)
    }

    func formatE164(_ text: String) -> String? {
        guard let parsedNumber = try? utility.parse(text, withRegion: defaultRegion) else { return nil }
        return utility.format(parsedNumber, toType: PhoneNumberFormat.e164)
    }

    func formatE164(_ text: String, region: String) -> String? {
        guard let parsedNumber = try? utility.parse(text, withRegion: region) else { return nil }
        return utility.format(parsedNumber, toType: PhoneNumberFormat.e164)
    }

    func formatInternational(_ text: String) -> String? {
        guard let parsedNumber = try? utility.parse(text, withRegion: defaultRegion) else { return nil }
        return utility.format(parsedNumber, toType: PhoneNumberFormat.international)
    }

    func formatInternational(_ text: String, region: String) -> String? {
        guard let parsedNumber = try? utility.parse(text, withRegion: region) else { return nil }
        return utility.format(parsedNumber, toType: PhoneNumberFormat.international)
    }

    func formatNational(_ text: String) -> String? {
        guard let parsedNumber = try? utility.parse(text, withRegion: defaultRegion) else { return nil }
        return utility.format(parsedNumber, toType: PhoneNumberFormat.national)
    }

    func formatNational(_ text: String, region: String) -> String? {
        guard let parsedNumber = try? utility.parse(text, withRegion: region) else { return nil }
        return utility.format(parsedNumber, toType: PhoneNumberFormat.national)
    }

    // MARK: - Region helpers

    var currentRegion: String { defaultRegion }

    func allRegions() -> [String] {
        // Exclude non-geographic entity "001" (World, e.g., +979)
        utility.allCountries().filter { $0 != "001" }.sorted()
    }

    func dialCode(for region: String) -> String? {
        guard let code = utility.countryCode(for: region) else { return nil }
        return "+\(code)"
    }

    func localizedRegionName(for region: String, locale: Locale = .current) -> String {
        if let name = locale.localizedString(forRegionCode: region) { return name }
        return region
    }
}
