//
//  UnityAdsAdapterFullscreenAd.swift
//  HeliumAdapterUnityAds
//
//  Created by Daniel Barros on 10/6/22.
//

import UIKit
import HeliumSdk
import UnityAds

/// The Helium UnityAds adapter fullscreen ad.
final class UnityAdsAdapterFullscreenAd: UnityAdsAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }
    
    /// A unique identifier passed in UnityAds load and show calls to identify the payload
    private let payloadIdentifier = UUID().uuidString
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        // Generate the UnityAds load options with the adm
        guard let options = UADSLoadOptions() else {
            let error = error(.loadFailure, description: "Failed to create UnityAds UADSLoadOptions")
            log(.loadFailed(error))
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
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        
        // Generate the UnityAds show options
        guard let options = UADSShowOptions() else {
            let error = error(.showFailure, description: "Failed to create UnityAds UADSShowOptions")
            log(.showFailed(error))
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

extension UnityAdsAdapterFullscreenAd: UnityAdsLoadDelegate {
    
    func unityAdsAdLoaded(_ placementId: String) {
        // Report load success
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func unityAdsAdFailed(toLoad placementId: String, withError errorCode: UnityAdsLoadError, withMessage message: String) {
        // Report load failure
        let error = error(.loadFailure, description: "\(errorCode) \(message)")
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
}

extension UnityAdsAdapterFullscreenAd: UnityAdsShowDelegate {
    
    func unityAdsShowStart(_ placementId: String) {
        // Report show success
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func unityAdsShowFailed(_ placementId: String, withError errorCode: UnityAdsShowError, withMessage message: String) {
        // Report show failure
        let error = error(.showFailure, description: "\(errorCode) \(message)")
        log(.showFailed(error))
        showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func unityAdsShowComplete(_ placementId: String, withFinish state: UnityAdsShowCompletionState) {
        // Report reward if show completed without skipping on a rewarded ad
        if request.format == .rewarded && state == .showCompletionStateCompleted {
            log(.didReward)
            delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
        }
        // Report dismiss
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
    
    func unityAdsShowClick(_ placementId: String) {
        // Report click
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
}
