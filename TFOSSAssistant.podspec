Pod::Spec.new do |s|
  s.name         = "TFOSSAssistant"
  s.version      = "0.0.1"
  s.summary      = "时光流影 iOS AliyunOSS"
  s.homepage     = "https://github.com/TimeFaceCoder/TFOSSAssistant"
  s.license      = "Copyright (C) 2015 TimeFace, Inc.  All rights reserved."
  s.author             = { "Melvin" => "yangmin@timeface.cn" }
  s.social_media_url   = "http://www.timeface.cn"
  s.ios.deployment_target = "7.1"
  s.source       = { :git => "https://github.com/TimeFaceCoder/TFOSSAssistant.git"}
  s.source_files  = "TFOSSAssistant/**/*.{h,m}"
  s.requires_arc = true
  s.dependency 'EGOCache'
  s.dependency 'AliyunOSSiOS', :git => 'https://github.com/aliyun/AliyunOSSiOS.git'
end
