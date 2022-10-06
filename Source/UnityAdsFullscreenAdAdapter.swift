//
//  UnityAdsFullscreenAdAdapter.swift
//  HeliumAdapterUnityAds
//
//  Created by Daniel Barros on 10/6/22.
//

import UIKit
import HeliumSdk
import UnityAds

/// The Helium UnityAds ad adapter for interstitial and rewarded ads.
final class UnityAdsFullscreenAdAdapter: NSObject, PartnerAdAdapter {
    
    /// The associated partner adapter.
    let adapter: PartnerAdapter
    
    /// The ad request containing data relevant to load operation.
    private let request: PartnerAdLoadRequest
    
    /// The partner ad delegate to send ad life-cycle events to.
    private weak var partnerAdDelegate: PartnerAdDelegate?
        
    /// A PartnerAd object to send in ad life-cycle events.
    private lazy var partnerAd = PartnerAd(ad: nil, details: [:], request: request)
    
    /// A unique identifier passed in UnityAds load and show calls to identify the payload
    private let payloadIdentifier = UUID().uuidString
    
    /// The completion for the ongoing load operation.
    private var loadCompletion: ((Result<PartnerAd, Error>) -> Void)?

    /// The completion for the ongoing show operation.
    private var showCompletion: ((Result<PartnerAd, Error>) -> Void)?
    
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, partnerAdDelegate: PartnerAdDelegate) throws {
        guard !request.partnerPlacement.isEmpty else {
            throw adapter.error(.loadFailure(request), description: "Empty placement")
        }
        self.adapter = adapter
        self.request = request
        self.partnerAdDelegate = partnerAdDelegate
    }
    
    /// Loads an ad.
    /// - note: Do not call this method directly, `ModularPartnerAdapter` will take care of it when needed.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<HeliumSdk.PartnerAd, Error>) -> Void) {
        // Generate the UnityAds load options with the adm
        guard let options = UADSLoadOptions() else {
            let error = error(.loadFailure(request), description: "Failed to create UnityAds UADSLoadOptions")
            completion(.failure(error))
            return
        }
        if let adm = request.adm {
            options.objectId = payloadIdentifier
            options.adMarkup = adm
        }
        // Load
        loadCompletion = completion
        UnityAds.load(request.partnerPlacement, options: options, loadDelegate: self)
    }
    
    /// Shows a loaded ad.
    /// - note: Do not call this method directly, `ModularPartnerAdapter` will take care of it when needed.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<HeliumSdk.PartnerAd, Error>) -> Void) {
        // Generate the UnityAds show options
        guard let options = UADSShowOptions() else {
            let error = error(.showFailure(partnerAd), description: "Failed to create UnityAds UADSShowOptions")
            completion(.failure(error))
            return
        }
        options.objectId = payloadIdentifier
        
        // Show
        showCompletion = completion
        // UnityAds makes use of UI-related APIs directly from the thread show() is called, so we need to do it on the main thread
        DispatchQueue.main.async { [self] in
            UnityAds.show(viewController, placementId: request.partnerPlacement, options: options, showDelegate: self)
        }
    }
}

extension UnityAdsFullscreenAdAdapter: UnityAdsLoadDelegate {
    
    func unityAdsAdLoaded(_ placementId: String) {
        // Report load success
        loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func unityAdsAdFailed(toLoad placementId: String, withError errorCode: UnityAdsLoadError, withMessage message: String) {
        // Report load failure
        let error = error(.loadFailure(request), description: "\(errorCode) \(message)")
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
}

extension UnityAdsFullscreenAdAdapter: UnityAdsShowDelegate {
    
    func unityAdsShowStart(_ placementId: String) {
        // Report show success
        showCompletion?(.success(partnerAd)) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func unityAdsShowFailed(_ placementId: String, withError errorCode: UnityAdsShowError, withMessage message: String) {
        // Report show failure
        let error = error(.showFailure(partnerAd), description: "\(errorCode) \(message)")
        showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func unityAdsShowComplete(_ placementId: String, withFinish state: UnityAdsShowCompletionState) {
        // Report reward if show completed without skipping on a rewarded ad
        if request.format == .rewarded && state == .showCompletionStateCompleted {
            let reward = Reward(amount: nil, label: nil)
            log(.didReward(partnerAd, reward: reward))
            partnerAdDelegate?.didReward(partnerAd, reward: reward)
        }
        // Report dismiss
        log(.didDismiss(partnerAd, error: nil))
        partnerAdDelegate?.didDismiss(partnerAd, error: nil)
    }
    
    func unityAdsShowClick(_ placementId: String) {
        // Report click
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd)
    }
}
