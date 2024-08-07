Pod::Spec.new do |spec|
  spec.name        = 'ChartboostMediationAdapterUnityAds'
  spec.version     = '5.4.12.0.0'
  spec.license     = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.homepage    = 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-unity-ads'
  spec.authors     = { 'Chartboost' => 'https://www.chartboost.com/' }
  spec.summary     = 'Chartboost Mediation iOS SDK Unity Ads adapter.'
  spec.description = 'Unity Ads Adapters for mediating through Chartboost Mediation. Supported ad formats: Banner, Interstitial, and Rewarded.'

  # Source
  spec.module_name  = 'ChartboostMediationAdapterUnityAds'
  spec.source       = { :git => 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-unity-ads.git', :tag => spec.version }
  spec.resource_bundles = { 'ChartboostMediationAdapterUnityAds' => ['PrivacyInfo.xcprivacy'] }
  spec.source_files = 'Source/**/*.{swift}'

  # Minimum supported versions
  spec.swift_version         = '5.0'
  spec.ios.deployment_target = '13.0'

  # System frameworks used
  spec.ios.frameworks = ['Foundation', 'UIKit']
  
  # This adapter is compatible with all Chartboost Mediation 5.X versions of the SDK.
  spec.dependency 'ChartboostMediationSDK', '~> 5.0'

  # Partner network SDK and version that this adapter is certified to work with.
  spec.dependency 'UnityAds', '~> 4.12.0'
  
  # The partner network SDK is a static framework which requires the static_framework option.
  spec.static_framework = true
end
