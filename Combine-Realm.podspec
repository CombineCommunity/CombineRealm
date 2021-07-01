Pod::Spec.new do |s|

  s.name             = "Combine-Realm"
  s.version          = "2.0.2"
  s.summary          = "A Combine wrapper of Realm's notifications and write bindings"

  s.description      = <<-DESC
    This is a Combine extension that provides an easy to use way to use Realm's natively reactive collection types as a Publishers
                       DESC

  s.homepage         = "https://github.com/CombineCommunity/CombineRealm.git"
  s.license          = 'MIT'
  s.author           = { "Istvan Kreisz" => "kreiszdev@gmail.com", "Combine Community" => "cocoapods@combine.community" }
  s.source           = { :git => "https://github.com/CombineCommunity/CombineRealm.git", :tag => s.version.to_s }
  s.source_files     = 'Sources/CombineRealm/*'

  s.requires_arc = true

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '6.0'

  s.frameworks = 'Combine'

  s.swift_version    = "5.1"

  s.dependency 'RealmSwift', '~> 10'

end
