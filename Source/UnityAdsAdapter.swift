//
//  UnityAdsAdapter.swift
//  HeliumAdapterUnityAds
//
//  Created by Daniel Barros on 10/6/22.
//

import Foundation
import HeliumSdk
import UnityAds

/// The Helium UnityAds adapter.
final class UnityAdsAdapter: NSObject, ModularPartnerAdapter {
    
    /// The version of the partner SDK, e.g. "5.13.2"
    let partnerSDKVersion = UnityAds.getVersion()
    
    /// The version of the adapter, e.g. "2.5.13.2.0"
    /// The first number is Helium SDK's major version. The next 3 numbers are the partner SDK version. The last number is the build version of the adapter.
    let adapterVersion = "4.4.4.1.0"
    
    /// The partner's identifier.
    let partnerIdentifier = "unity"
    
    /// The partner's name in a human-friendly version.
    let partnerDisplayName = "Unity Ads"
    
    /// Created ad adapter instances, keyed by the request identifier.
    /// You should not generally need to modify this property in your adapter implementation, since it is managed by the
    /// `ModularPartnerAdapter` itself on its default implementation for `PartnerAdapter` load, show and invalidate methods.
    var adAdapters: [String: PartnerAdAdapter] = [:]
    
    /// The setUp completion received on setUp(), to be executed when UnityAds reports back its initialization status.
    private var setUpCompletion: ((Error?) -> Void)?
    
    /// The last value set on `setGDPRApplies(_:)`.
    private var gdprApplies: Bool?
    
    /// The last value set on `setGDPRConsentStatus(_:)`.
    private var gdprStatus: GDPRConsentStatus?
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        
        // Get credentials, fail early if they are unavailable
        guard let gameID = configuration.gameID else {
            let error = error(.missingSetUpParameter(key: .gameIDKey))
            log(.setUpFailed(error))
            completion(error)
            return
        }
        
        // Set mediation metadata
        let metaData = UADSMediationMetaData()
        metaData.setName("Helium")
        metaData.setVersion(Helium.sdkVersion)
        metaData.set(.adapterVersionKey, value: adapterVersion)
        metaData.commit()
        
        // Initialize UnityAds
        setUpCompletion = completion
        UnityAds.initialize(gameID, testMode: false, initializationDelegate: self)
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]) -> Void) {
        // UnityAds does not currently provide any bidding token
        log(.fetchBidderInfoStarted(request))
        log(.fetchBidderInfoSucceeded(request))
        completion([:])
    }
    
    /// Indicates if GDPR applies or not.
    /// - parameter applies: `true` if GDPR applies, `false` otherwise.
    func setGDPRApplies(_ applies: Bool) {
        // Save value and set GDPR on UnityAds using both gdprApplies and gdprStatus
        gdprApplies = applies
        updateGDPRConsent()
    }
    
    /// Indicates the user's GDPR consent status.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPRConsentStatus(_ status: GDPRConsentStatus) {
        // Save value and set GDPR on UnityAds using both gdprApplies and gdprStatus
        gdprStatus = status
        updateGDPRConsent()
    }
    
    private func updateGDPRConsent() {
        // Consent only applies if the user is subject to GDPR
        guard gdprApplies == true, let gdprStatus = gdprStatus else {
            return
        }
        let value = gdprStatus == .granted ? true : false
        let key = String.gdprConsentKey
        let gdprMetaData = UADSMetaData()
        gdprMetaData.set(key, value: value)
        gdprMetaData.commit()
        log(.privacyUpdated(setting: "UADSMetaData", value: [key: value]))
    }
    
    /// Indicates the CCPA status both as a boolean and as a IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: A IAB-compliant string indicating the CCPA status.
    func setCCPAConsent(hasGivenConsent: Bool, privacyString: String?) {
        let key = String.privacyConsentKey
        let privacyMetaData = UADSMetaData()
        privacyMetaData.set(key, value: hasGivenConsent)
        privacyMetaData.commit()
        log(.privacyUpdated(setting: "UADSMetaData", value: [key: hasGivenConsent]))
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isSubject: `true` if the user is subject, `false` otherwise.
    func setUserSubjectToCOPPA(_ isSubject: Bool) {
        let value = !isSubject  // Subject to COPPA means the user is not over the age limit.
        let key = String.userOverAgeLimitKey
        let ageGateMetaData = UADSMetaData()
        ageGateMetaData.set(key, value: value)
        ageGateMetaData.commit()
        log(.privacyUpdated(setting: "UADSMetaData", value: [key: value]))
    }
    
    /// Provides a new ad adapter in charge of communicating with a single partner ad instance.
    func makeAdAdapter(request: PartnerAdLoadRequest, partnerAdDelegate: PartnerAdDelegate) throws -> PartnerAdAdapter {
        switch request.format {
        case .interstitial, .rewarded:
            return try UnityAdsFullscreenAdAdapter(adapter: self, request: request, partnerAdDelegate: partnerAdDelegate)
        case .banner:
            return try UnityAdsBannerAdAdapter(adapter: self, request: request, partnerAdDelegate: partnerAdDelegate)
        }
    }
}

extension UnityAdsAdapter: UnityAdsInitializationDelegate {
    
    func initializationComplete() {
        // Report initialization success
        log(.setUpSucceded)
        setUpCompletion?(nil) ?? log("Setup result ignored")
        setUpCompletion = nil
    }
    
    func initializationFailed(_ errorCode: UnityAdsInitializationError, withMessage message: String) {
        // Report initialization failure
        let error = error(.setUpFailure, description: "\(errorCode) \(message)")
        log(.setUpFailed(error))
        setUpCompletion?(error) ?? log("Setup result ignored")
        setUpCompletion = nil
    }
}

/// Convenience extension to access UnityAds credentials from the configuration.
private extension PartnerConfiguration {
    var gameID: String? { credentials[.gameIDKey] as? String }
}

private extension String {
    /// UnityAds game ID credentials key.
    static let gameIDKey = "game_id"
    /// UnityAds metadata adapter version key.
    static let adapterVersionKey = "adapter_version"
    /// UnityAds privacy userOverAgeLimit key.
    static let userOverAgeLimitKey = "privacy.useroveragelimit"
    /// UnityAds privacy GDPR consent key.
    static let gdprConsentKey = "gdpr.consent"
    /// UnityAds privacy consent key.
    static let privacyConsentKey = "privacy.consent"
}
