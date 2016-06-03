Pod::Spec.new do |s|
  s.name         = "LDSAnnotations"
  s.version      = "1.1.0"
  s.summary      = "Swift client library for LDS annotation sync."
  s.author       = 'Hilton Campbell'
  s.homepage     = "https://github.com/CrossWaterBridge/LDSAnnotations"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.source       = { :git => "https://github.com/CrossWaterBridge/LDSAnnotations.git", :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '9.0'
  s.source_files = 'LDSAnnotations/*.swift'
  s.requires_arc = true
  
  s.dependency 'PSOperations'
  s.dependency 'SQLite.swift'
  s.dependency 'Swiftification'
  s.dependency 'Locksmith'
end
