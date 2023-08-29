// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import UIKit
import UnityAds

/// The Chartboost Mediation Unity Ads adapter banner ad.
final class UnityAdsAdapterBannerAd: UnityAdsAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)

        // Fail if we cannot fit a fixed size banner in the requested size.
        guard let size = fixedBannerSize(for: request.size ?? IABStandardAdSize) else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            return completion(.failure(error))
        }

        // Save completion for later
        loadCompletion = completion
        
        // Create the banner
        let banner = UADSBannerView(placementId: request.partnerPlacement, size: size)
        banner.delegate = self
        inlineView = banner
        
        // Load it
        banner.load()
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

        var partnerDetails: [String: String] = [:]
        if let loadedSize = fixedBannerSize(for: request.size ?? IABStandardAdSize) {
            partnerDetails["bannerWidth"] = "\(loadedSize.width)"
            partnerDetails["bannerHeight"] = "\(loadedSize.height)"
            partnerDetails["bannerType"] = "0" // Fixed banner
        }
        loadCompletion?(.success(partnerDetails)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func bannerViewDidShow(_ bannerView: UADSBannerView!) {
        // Report show success
        log(.showSucceeded)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func bannerViewDidError(_ bannerView: UADSBannerView?, error: UADSBannerError?) {
        // Report load failure
        let error = error ?? self.error(.loadFailureUnknown)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func bannerViewDidClick(_ bannerView: UADSBannerView?) {
        // Report click
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func bannerViewDidLeaveApplication(_ bannerView: UADSBannerView!) {
        log(.delegateCallIgnored)
    }
}

// MARK: - Helpers
extension UnityAdsAdapterBannerAd {
    private func fixedBannerSize(for requestedSize: CGSize) -> CGSize? {
        let sizes = [IABLeaderboardAdSize, IABMediumAdSize, IABStandardAdSize]
        // Find the largest size that can fit in the requested size.
        for size in sizes {
            // If height is 0, the pub has requested an ad of any height, so only the width matters.
            if requestedSize.width >= size.width &&
                (size.height == 0 || requestedSize.height >= size.height) {
                return size
            }
        }
        // The requested size cannot fit any fixed size banners.
        return nil
    }
}
