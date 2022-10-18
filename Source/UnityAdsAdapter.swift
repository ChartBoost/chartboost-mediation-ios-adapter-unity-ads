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
final class UnityAdsAdapter: NSObject, PartnerAdapter {
    
    /// The version of the partner SDK.
    let partnerSDKVersion = UnityAds.getVersion()
    
    /// The version of the adapter.
    /// The first digit is Helium SDK's major version. The last digit is the build version of the adapter. The intermediate digits correspond to the partner SDK version.
    let adapterVersion = "4.4.4.1.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "unity"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "Unity Ads"
        
    /// The setUp completion received on setUp(), to be executed when UnityAds reports back its initialization status.
    private var setUpCompletion: ((Error?) -> Void)?
    
    /// The last value set on `setGDPRApplies(_:)`.
    private var gdprApplies: Bool?
    
    /// The last value set on `setGDPRConsentStatus(_:)`.
    private var gdprStatus: GDPRConsentStatus?
    
    /// The designated initializer for the adapter.
    /// Helium SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Helium SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) {}
    
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
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]?) -> Void) {
        // UnityAds does not currently provide any bidding token
        completion(nil)
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
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
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
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Helium SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Helium SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        guard !request.partnerPlacement.isEmpty else {
            throw error(.invalidPlacement)
        }
        switch request.format {
        case .interstitial, .rewarded:
            return try UnityAdsAdapterFullscreenAd(adapter: self, request: request, delegate: delegate)
        case .banner:
            return try UnityAdsAdapterBannerAd(adapter: self, request: request, delegate: delegate)
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
