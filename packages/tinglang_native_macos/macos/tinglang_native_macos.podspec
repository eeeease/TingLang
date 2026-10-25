# CocoaPods fallback for projects with Swift Package Manager disabled.
Pod::Spec.new do |s|
  s.name             = 'tinglang_native_macos'
  s.version          = '0.1.0'
  s.summary          = 'macOS native backends for Tinglang.'
  s.homepage         = 'https://github.com/eeeease/TingLang'
  s.license          = { :type => 'AGPL-3.0-only', :file => '../../../LICENSE' }
  s.author           = { 'Tinglang contributors' => 'noreply@github.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'tinglang_native_macos/Sources/tinglang_native_macos/**/*.swift'
  s.resource_bundles = {'tinglang_native_macos_privacy' => ['tinglang_native_macos/Sources/tinglang_native_macos/PrivacyInfo.xcprivacy']}
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '14.2'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
