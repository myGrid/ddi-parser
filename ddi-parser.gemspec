# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "models/version"

Gem::Specification.new do |s|
  s.name        = "ddi-parser"
  s.version     = DDI::Parser::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ian Dunlop"]
  s.email       = ["ian.dunlop@manchester.ac.uk"]
  s.homepage    = "http://github.com/mygrid/ddi-parser"
  s.summary     = %q{API for parsing ddi metadata files and returning results}
  s.description = %q{This gem parses ddi metadata files}

  s.rubyforge_project = "ddi-parser"
  candidates         = Dir.glob("{bin,lib,test}/**/*")
  s.files            = candidates.delete_if {|item| item.include?("rdoc")}
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  # s.add_dependency("nokogiri", "1.4.4")
  s.add_dependency("libxml-ruby","1.1.4")
end
