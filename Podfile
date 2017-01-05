source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '8.0'

use_frameworks!
workspace 'LDSAnnotations'

target 'LDSAnnotations' do
    project 'LDSAnnotations.xcodeproj'
    
    pod 'ProcedureKit', '4.0.0.beta.4'
    pod 'SQLite.swift'
    pod 'Swiftification'
    pod 'Locksmith'
    
    target 'LDSAnnotationsTests' do
    end

    target 'LDSAnnotationsDemo' do
        project 'LDSAnnotationsDemo.xcodeproj'
    end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end

