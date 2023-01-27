// Copyright 2022-2023 Chartboost, Inc.
// 
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

//
//  UnityAdsAdapter.swift
//  ChartboostMediationAdapterUnityAds
//
//  Created by Daniel Barros on 10/6/22.
//

import ChartboostMediationSDK
import Foundation
import UnityAds

/// The Chartboost Mediation Unity Ads adapter.
final class UnityAdsAdapter: NSObject, PartnerAdapter {
    
    /// The version of the partner SDK.
    let partnerSDKVersion = UnityAds.getVersion()
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.4.4.1.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "unity"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "Unity Ads"
        
    /// The setUp completion received on setUp(), to be executed when Unity Ads reports back its initialization status.
    private var setUpCompletion: ((Error?) -> Void)?
    
    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) {}
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        
        // Get credentials, fail early if they are unavailable
        guard let gameID = configuration.gameID else {
            let error = error(.initializationFailureInvalidCredentials, description: "Missing \(String.gameIDKey)")
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
        
        // Initialize Unity Ads
        setUpCompletion = completion
        UnityAds.initialize(gameID, testMode: false, initializationDelegate: self)
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]?) -> Void) {
        // Unity Ads does not currently provide any bidding token
        completion(nil)
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
        // Consent only applies if the user is subject to GDPR
        guard applies == true else {
            return
        }
        let value = status == .granted
        let key = String.gdprConsentKey
        let gdprMetaData = UADSMetaData()
        gdprMetaData.set(key, value: value)
        gdprMetaData.commit()
        log(.privacyUpdated(setting: "UADSMetaData", value: [key: value]))
    }
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
    func setCCPA(hasGivenConsent: Bool, privacyString: String) {
        let key = String.privacyConsentKey
        let privacyMetaData = UADSMetaData()
        privacyMetaData.set(key, value: hasGivenConsent)
        privacyMetaData.commit()
        log(.privacyUpdated(setting: "UADSMetaData", value: [key: hasGivenConsent]))
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
        let value = !isChildDirected  // Child-directed means the user is not over the age limit.
        let key = String.userOverAgeLimitKey
        let ageGateMetaData = UADSMetaData()
        ageGateMetaData.set(key, value: value)
        ageGateMetaData.commit()
        log(.privacyUpdated(setting: "UADSMetaData", value: [key: value]))
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        guard !request.partnerPlacement.isEmpty else {
            throw error(.loadFailureInvalidPartnerPlacement)
        }
        switch request.format {
        case .interstitial, .rewarded:
            return try UnityAdsAdapterFullscreenAd(adapter: self, request: request, delegate: delegate)
        case .banner:
            return try UnityAdsAdapterBannerAd(adapter: self, request: request, delegate: delegate)
        @unknown default:
            throw error(.loadFailureUnsupportedAdFormat)
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
        let error = partnerError(errorCode.rawValue, description: message)
        log(.setUpFailed(error))
        setUpCompletion?(error) ?? log("Setup result ignored")
        setUpCompletion = nil
    }
}

/// Convenience extension to access Unity Ads credentials from the configuration.
private extension PartnerConfiguration {
    var gameID: String? { credentials[.gameIDKey] as? String }
}

private extension String {
    /// Unity Ads game ID credentials key.
    static let gameIDKey = "game_id"
    /// Unity Ads metadata adapter version key.
    static let adapterVersionKey = "adapter_version"
    /// Unity Ads privacy userOverAgeLimit key.
    static let userOverAgeLimitKey = "privacy.useroveragelimit"
    /// Unity Ads privacy GDPR consent key.
    static let gdprConsentKey = "gdpr.consent"
    /// Unity Ads privacy consent key.
    static let privacyConsentKey = "privacy.consent"
}
