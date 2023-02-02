// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import UIKit
import UnityAds

/// Base class for Chartboost Mediation Unity Ads adapter ads.
class UnityAdsAdapterAd: NSObject {
    
    /// The partner adapter that created this ad.
    let adapter: PartnerAdapter
    
    /// The ad load request associated to the ad.
    /// It should be the one provided on `PartnerAdapter.makeAd(request:delegate:)`.
    let request: PartnerAdLoadRequest
    
    /// The partner ad delegate to send ad life-cycle events to.
    /// It should be the one provided on `PartnerAdapter.makeAd(request:delegate:)`.
    weak var delegate: PartnerAdDelegate?
    
    /// The completion for the ongoing load operation.
    var loadCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?

    /// The completion for the ongoing show operation.
    var showCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        self.adapter = adapter
        self.request = request
        self.delegate = delegate
    }
}
