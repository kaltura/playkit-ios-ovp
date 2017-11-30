Pod::Spec.new do |s|
  
  s.name             = 'PlayKitOVP'
  s.version          = '1.0.0'
  s.summary          = 'PlayKitOVP -- OVP framework for iOS'
  s.homepage         = 'https://github.com/kaltura/playkit-ios-ovp'
  s.license          = { :type => 'AGPLv3', :file => 'LICENSE' }
  s.author           = { 'Kaltura' => 'community@kaltura.com' }
  s.source           = { :git => 'https://github.com/kaltura/playkit-ios-ovp.git', :tag => 'v' + s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.source_files = 'Sources/**/*'
  s.dependency 'PlayKit/Core'
  s.dependency 'KalturaNetKit'
end

