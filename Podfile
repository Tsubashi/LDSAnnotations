source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '8.0'

use_frameworks!
workspace 'LDSAnnotations'

target 'LDSAnnotations' do
    project 'LDSAnnotations.xcodeproj'
    
    pod 'Operations'
    pod 'SQLite.swift', '0.10.1'
    pod 'Swiftification', '6.0.1'
    pod 'Locksmith', '2.0.8'
    
    target 'LDSAnnotationsTests' do
    end

    target 'LDSAnnotationsDemo' do
        project 'LDSAnnotationsDemo.xcodeproj'
    end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '2.3'
        end
    end
end
