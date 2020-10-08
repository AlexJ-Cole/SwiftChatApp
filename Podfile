# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'FireChat' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

#Firebase
  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  pod 'Firebase/Database'
  pod 'Firebase/Analytics'
  pod 'Firebase/Storage'
  pod 'Firebase/Crashlytics'

#Facebook
  pod 'FBSDKLoginKit'

#Google Sign In
  pod 'GoogleSignIn'

#Utility
  pod 'MessageKit'
  pod 'JGProgressHUD'
  pod 'RealmSwift'
  pod 'SDWebImage'

  target 'FireChatTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'FireChatUITests' do
    # Pods for testing
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if Gem::Version.new('8.0') > Gem::Version.new(config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'])
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '8.0'
      end
    end
  end
end
