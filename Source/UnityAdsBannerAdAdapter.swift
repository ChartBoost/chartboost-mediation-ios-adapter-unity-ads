//
//  UnityAdsBannerAdAdapter.swift
//  HeliumAdapterUnityAds
//
//  Created by Daniel Barros on 10/6/22.
//

import UIKit
import HeliumSdk
import UnityAds

/// The Helium UnityAds ad adapter for banner ads.
final class UnityAdsBannerAdAdapter: NSObject, PartnerAdAdapter {
    
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
        // Save completion for later
        loadCompletion = completion
        
        // UnityAds banner inherits from UIView so we need to instantiate it on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create the banner
            let banner = UADSBannerView(placementId: self.request.partnerPlacement, size: self.request.size ?? IABStandardAdSize)
            banner.delegate = self
            self.partnerAd = PartnerAd(ad: banner, details: [:], request: self.request)
            
            // Load it
            banner.load()
        }
    }
    
    /// Shows a loaded ad.
    /// - note: Do not call this method directly, `ModularPartnerAdapter` will take care of it when needed.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<HeliumSdk.PartnerAd, Error>) -> Void) {
        // no-op
    }
}

extension UnityAdsBannerAdAdapter: UADSBannerViewDelegate {
    
    func bannerViewDidLoad(_ bannerView: UADSBannerView?) {
        // Report load success
        loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func bannerViewDidError(_ bannerView: UADSBannerView?, partnerError: UADSBannerError?) {
        // Report load failure
        let error = error(.loadFailure(request), error: partnerError)
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func bannerViewDidClick(_ bannerView: UADSBannerView?) {
        // Report click
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd)
    }
}
