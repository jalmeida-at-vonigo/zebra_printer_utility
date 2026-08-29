#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zebrautil.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zebrautil'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.static_framework = true
  
  # Zebra Link-OS SDK, as the XCFramework Zebra ships.
  #
  # Do NOT go back to vendoring a flat libZSDK_API.a. That file is a non-fat,
  # device-only arm64 archive, so linking it into an iOS-Simulator build fails
  # with "building for 'iOS-simulator', but linking in object file built for
  # 'iOS'" — the whole app then cannot be built for any simulator, which blocks
  # every simulator-based test and demo, not just printing.
  #
  # The XCFramework carries both slices: ios-arm64 for devices and
  # ios-arm64_x86_64-simulator for simulators on both Apple Silicon and Intel.
  s.vendored_frameworks = 'ZSDK_API.xcframework'
  s.preserve_paths = 'ZSDK_API.xcframework'

  # Required frameworks
  s.frameworks = 'CoreBluetooth', 'QuartzCore'
  s.libraries = 'z'
  
  # Linker flags
  s.xcconfig = { 
    'OTHER_LDFLAGS' => '-framework CoreBluetooth -framework QuartzCore -lz'
  }
  
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'zebrautil_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
  
  # Add Info.plist configuration for Bluetooth permissions
  s.info_plist = {
    'NSBluetoothAlwaysUsageDescription' => 'This app uses Bluetooth to discover and connect to Zebra printers for printing labels and receipts.',
    'NSBluetoothPeripheralUsageDescription' => 'This app uses Bluetooth to discover and connect to Zebra printers for printing labels and receipts.',
    'NSLocalNetworkUsageDescription' => 'This app uses the local network to discover and connect to Zebra printers on your network.',
    'NSBonjourServices' => ['_ipp._tcp', '_printer._tcp']
  }
end
