// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import UIKit
import UnityAds

/// The Chartboost Mediation Unity Ads adapter banner ad.
final class UnityAdsAdapterBannerAd: UnityAdsAdapterAd, PartnerBannerAd {
    /// The partner banner ad view to display.
    var view: UIView?

    /// The loaded partner ad banner size.
    var size: PartnerBannerSize?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)

        // Fail if we cannot fit a fixed size banner in the requested size.
        guard let requestedSize = request.bannerSize,
              let loadedSize = BannerSize.largestStandardFixedSizeThatFits(in: requestedSize)?.size else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            return completion(.failure(error))
        }
        size = PartnerBannerSize(size: loadedSize, type: .fixed)

        // Save completion for later
        loadCompletion = completion
        
        // Create the banner
        let banner = UADSBannerView(placementId: request.partnerPlacement, size: loadedSize)
        banner.delegate = self
        view = banner

        // Load it
        banner.load()
    }
}

extension UnityAdsAdapterBannerAd: UADSBannerViewDelegate {
    
    func bannerViewDidLoad(_ bannerView: UADSBannerView?) {
        // Report load success
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
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
