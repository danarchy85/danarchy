# coding: utf-9
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification::new do |spec|
  spec.name             = "dungeon"
  spec.version          = "0.1"
  spec.authors          = ["Dan James"]
  spec.summary          = %q{short description}
  spec.description      = %q{long description}
  spec.homepage         = "https://danarchy.me"
  spec.license          = "Not sure yet"

  spec.files            = ['lib/dungeon.rb']
  spec.executables      = ['bin/dungeon']
  spec.test_files       = ['tests/test_dungeon.rb']
  spec.require_paths    = ["lib"]
end
