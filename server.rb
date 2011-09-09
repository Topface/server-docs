#!/usr/bin/env ruby


help = <<HELP
server-docs is a simple engine to serve docs for vokrug clients developers

Basic Command Line Usage:
  ./server.rb [OPTIONS] [PATH]

        PATH                         The path to the server docs repository (default .).

Options:
HELP

require 'optparse'
require 'rubygems'
require 'gollum'

options = { 'port' => 5656, 'bind' => '0.0.0.0' }
wiki_options = {}

opts = OptionParser.new do |opts|
  opts.banner = help

  opts.on("--port [PORT]", "Bind port (default 4567).") do |port|
    options['port'] = port.to_i
  end

  opts.on("--host [HOST]", "Hostname or IP address to listen on (default 0.0.0.0).") do |host|
    options['bind'] = host
  end

  opts.on("--version", "Display current version.") do
    puts "Gollum " + Gollum::VERSION
    exit 0
  end

  opts.on("--config [CONFIG]", "Path to additional configuration file") do |config|
    options['config'] = config
  end

  opts.on("--irb", "Start an irb process with gollum loaded for the current wiki.") do
    options['irb'] = true
  end

  opts.on("--page-file-dir [PATH]", "Specify the sub directory for all page files (default: repository root).") do |path|
    wiki_options[:page_file_dir] = path
  end

  opts.on("--ref [REF]", "Specify the repository ref to use (default: master).") do |ref|
    wiki_options[:ref] = ref
  end
end

# Read command line options into `options` hash
begin
  opts.parse!
rescue OptionParser::InvalidOption
  puts "gollum: #{$!.message}"
  puts "gollum: try './server.rb --help' for more information"
  exit
end

gollum_path = ARGV[0] || Dir.pwd

if options['irb']
  require 'irb'
  # http://jameskilton.com/2009/04/02/embedding-irb-into-your-ruby-application/
  module IRB # :nodoc:
    def self.start_session(binding)
      unless @__initialized
        args = ARGV
        ARGV.replace(ARGV.dup)
        IRB.setup(nil)
        ARGV.replace(args)
        @__initialized = true
      end

      ws  = WorkSpace.new(binding)
      irb = Irb.new(ws)

      @CONF[:IRB_RC].call(irb.context) if @CONF[:IRB_RC]
      @CONF[:MAIN_CONTEXT] = irb.context

      catch(:IRB_EXIT) do
        irb.eval_input
      end
    end
  end

  begin
    wiki = Gollum::Wiki.new(gollum_path, wiki_options)
    if !wiki.exist? then raise Grit::InvalidGitRepositoryError end
    puts "Loaded Gollum wiki at #{File.expand_path(gollum_path).inspect}."
    puts
    puts %(    page = wiki.page('page-name'))
    puts %(    # => <Gollum::Page>)
    puts
    puts %(    page.raw_data)
    puts %(    # => "# My wiki page")
    puts
    puts %(    page.formatted_data)
    puts %(    # => "<h1>My wiki page</h1>")
    puts
    puts "Check out the Gollum README for more."
    IRB.start_session(binding)
  rescue Grit::InvalidGitRepositoryError, Grit::NoSuchPathError
    puts "Invalid Gollum wiki at #{File.expand_path(gollum_path).inspect}"
    exit 0
  end
else
  require './app'
  Precious::App.set(:gollum_path, gollum_path)
  Precious::App.set(:wiki_options, wiki_options)

  Precious::App.run!(options)
end
