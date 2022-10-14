//
//  UnityAdsAdapterBannerAd.swift
//  HeliumAdapterUnityAds
//
//  Created by Daniel Barros on 10/6/22.
//

import UIKit
import HeliumSdk
import UnityAds

/// The Helium UnityAds adapter banner ad.
final class UnityAdsAdapterBannerAd: UnityAdsAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        // Save completion for later
        loadCompletion = completion
        
        // UnityAds banner inherits from UIView so we need to instantiate it on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create the banner
            let banner = UADSBannerView(placementId: self.request.partnerPlacement, size: self.request.size ?? IABStandardAdSize)
            banner.delegate = self
            self.inlineView = banner
            
            // Load it
            banner.load()
        }
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        // no-op
    }
}

extension UnityAdsAdapterBannerAd: UADSBannerViewDelegate {
    
    func bannerViewDidLoad(_ bannerView: UADSBannerView?) {
        // Report load success
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func bannerViewDidError(_ bannerView: UADSBannerView?, partnerError: UADSBannerError?) {
        // Report load failure
        let error = error(.loadFailure, error: partnerError)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func bannerViewDidClick(_ bannerView: UADSBannerView?) {
        // Report click
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
}
