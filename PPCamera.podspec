Pod::Spec.new do |s|
  s.name             = 'PPCamera'
  s.version          = '1.0.2'
  s.summary          = 'A short description of PPCamera.'
  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/gejiangs/PPCamera'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'intitni' => '664553782@qq.com' }
  s.source           = { :git => 'https://github.com/gejiangs/PPCamera.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.swift_versions = ['5.0']

  s.source_files = 'PPCamera/Classes/**/*'
end
