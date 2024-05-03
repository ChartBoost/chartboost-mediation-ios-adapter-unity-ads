// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import UnityAds

@objc public class UnityAdsAdapterConfiguration: NSObject, PartnerAdapterConfiguration {

    /// The version of the partner SDK.
    @objc public static var partnerSDKVersion: String {
        UnityAds.getVersion()
    }

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    @objc public static let adapterVersion = "4.4.10.0.0"

    /// The partner's unique identifier.
    @objc public static let partnerID = "unity"

    /// The human-friendly partner name.
    @objc public static let partnerDisplayName = "Unity Ads"

    /// Flag that can optionally be set to enable the partner's debug mode.
    /// Disabled by default.
    @objc public static var debugMode: Bool {
        get {
            UnityAds.getDebugMode()
        }
        set {
            UnityAds.setDebugMode(newValue)
            log("Test mode set to \(newValue)")
        }
    }

    /// Use to manually set the consent status on the Pangle SDK.
    /// This is generally unnecessary as the Mediation SDK will set the consent status automatically based on the latest consent info.
    @objc public static func setGDPRConsentOverride(_ consent: Bool) {
        isGDPRConsentOverriden = true
        // See https://docs.unity.com/ads/en/manual/GDPRCompliance
        let metadata = UADSMetaData()
        metadata.set("gdpr.consent", value: consent)
        metadata.commit()
        log("GDPR consent override set to \(consent)")
    }

    /// Use to manually set the consent status on the Pangle SDK.
    /// This is generally unnecessary as the Mediation SDK will set the consent status automatically based on the latest consent info.
    @objc public static func setPrivacyConsentOverride(_ consent: Bool) {
        isPrivacyConsentOverriden = true
        // See https://docs.unity.com/ads/en/manual/CCPACompliance
        let metadata = UADSMetaData()
        metadata.set("privacy.consent", value: consent)
        metadata.commit()
        log("Privacy consent override set to \(consent)")
    }

    /// Internal flag that indicates if the GDPR consent has been overriden by the publisher.
    static private(set) var isGDPRConsentOverriden = false

    /// Internal flag that indicates if the Privacy consent has been overriden by the publisher.
    static private(set) var isPrivacyConsentOverriden = false
}
