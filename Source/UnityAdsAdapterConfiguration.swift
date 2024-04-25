// Copyright 2023-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import Foundation
import UnityAds

@objc public class UnityAdsAdapterConfiguration: NSObject {

    /// The version of the partner SDK.
    @objc static var partnerSDKVersion: String {
        UnityAds.getVersion()
    }

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    @objc static let adapterVersion = "4.4.10.0.0"

    /// The partner's unique identifier.
    @objc static let partnerID = "unity"

    /// The human-friendly partner name.
    @objc static let partnerDisplayName = "Unity Ads"
}
