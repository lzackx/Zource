# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-zource/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-zource'
  spec.version       = CocoapodsZource::VERSION
  spec.authors       = ['lzackx']
  spec.email         = ['lzackx@lzackx.com']
  spec.description   = %q{CocoaPods Helper.}
  spec.summary       = %q{CocoaPods Helper.}
  spec.homepage      = 'https://github.com/lzackx/cocoapods-zource'
  spec.license       = 'MIT'

  spec.files         = Dir["lib/**/*.rb"] + %w{ README.md LICENSE.txt }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'cocoapods'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
end
