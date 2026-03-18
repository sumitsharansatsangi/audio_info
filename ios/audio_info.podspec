Pod::Spec.new do |s|
  s.name             = 'audio_info'
  s.version          = '0.0.6'
  s.summary          = 'Flutter plugin for audio metadata, artwork, and waveform access.'
  s.description      = <<-DESC
Read audio metadata, embedded artwork, and lightweight waveform samples from local audio files.
                       DESC
  s.homepage         = 'https://github.com/sumitsharansatsangi/audio_info/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sumit Kumar' => 'support@kumpali.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
