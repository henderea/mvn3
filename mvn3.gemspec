# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mvn3/version'

Gem::Specification.new do |spec|
  spec.name          = 'mvn3'
  spec.version       = Mvn3::VERSION
  spec.authors       = ['Eric Henderson']
  spec.email         = ['henderea@gmail.com']
  spec.summary       = %q{A command-based version of mvn2 (Maven helper)}
  spec.description   = %q{This is a alternate version of the mvn2 gem that uses thor to enable commands instead of having to rely only on flags.}
  spec.homepage      = 'https://github.com/henderea/mvn3'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

   spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake', '~> 10.0'

  spec.add_dependency 'everyday-cli-utils', '~> 1.7'
  spec.add_dependency 'everyday-plugins', '~> 1.2'
  spec.add_dependency 'everyday_thor_util', '~> 1.4', '>= 1.4.1'
  spec.add_dependency 'thor', '~> 0.19'

end
