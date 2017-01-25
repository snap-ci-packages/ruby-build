require 'rubygems'
require 'bundler/setup'
require 'snap_ci/parallel_tests'
require 'rubygems/version'

RUBY_VERSION_REGEX = /^\s+(jruby-)?([\d]+\.[\d]+\.[\d]+(?:\.[\d]+)?)$/
compile_opts = { :CC => '/usr/bin/gcc' }

extra_header_files = %w(debug.h eval_intern.h id.h insns.inc insns_info.inc iseq.h method.h node.h revision.h ruby_atomic.h thread_pthread.h version.h vm_core.h vm_opts.h)


task :clean do
  rm_rf 'log'
  rm_rf 'pkg'
end

task :init do
  sh("rbenv update")
  mkdir_p 'log'
  mkdir_p 'pkg'
end

module Retriable
  # This will catch any exception and retry twice (three tries total):
  #   with_retries { ... }
  #
  # This will catch any exception and retry four times (five tries total):
  #   with_retries(:limit => 5) { ... }
  #
  # This will catch a specific exception and retry once (two tries total):
  #   with_retries(Some::Error, :limit => 2) { ... }
  #
  # You can also sleep inbetween tries. This is helpful if you're hoping
  # that some external service recovers from its issues.
  #   with_retries(Service::Error, :sleep => 1) { ... }
  #
  def with_retries(*args, &block)
    options = extract_options!(args)
    exceptions = args

    options[:limit] ||= 3
    options[:sleep] ||= 0
    exceptions = [Exception] if exceptions.empty?

    retried = 0
    begin
      yield
    rescue *exceptions => e
      if retried + 1 < options[:limit]
        retried += 1
        sleep options[:sleep]
        retry
      else
        raise e
      end
    end
  end

  private
  def extract_options!(array)
    array.last.is_a?(::Hash) ? array.pop : {}
  end
end

include Retriable

class Ruby
  attr_reader :full_version

  def initialize(full_version)
    @full_version = full_version
    @full_version.freeze
  end

  def to_s
    full_version
  end

  def build_command
    "rbenv install -f #{full_version}"
  end

  def dest_package_file_name
    "#{full_version}.tar.gz"
  end
end

OUTPUT_DIR = "pkg"

def fetch_versions_from_rbenv
  `rbenv install --list`.each_line.inject([]) do |memo, line|
    ruby_candidate = line.strip

    if %w(1.8.7-p375 1.9.2-p330 1.9.3-p551 2.0.0-p648).include?(ruby_candidate)
      memo << ruby_candidate
    elsif ruby_candidate !~ /^(1.8|1.9|2.0|jruby-1.5)/ && ruby_candidate =~ /^(jruby-)?([\d]+\.[\d]+\.[\d]+(?:\.[\d]+)?)$/
      memo << ruby_candidate
    end
    memo
  end
end

def rubies_to_build
  all_versions = fetch_versions_from_rbenv
  versions_to_build = SnapCI::ParallelTests.partition(:things => all_versions)
  $stdout.puts "Here is the list of rubies that will be built on this worker - #{versions_to_build.join(', ')}"
  versions_to_build.collect { |v| Ruby.new(v) }
end

desc 'build all rubies'
task :build => [:clean, :init] do
  rbenv_root = `rbenv root`.strip
  raise "rbenv not installed correctly?" if rbenv_root == ""
  build_target_path = File.join(rbenv_root, "versions")

  rubies_that_failed = []

  rubies_to_build.each do |ruby|
    if only_build_version = ENV['ONLY_BUILD']
      next if only_build_version != ruby.to_s
    end

    $stdout.puts "Building ruby #{ruby}"

    rm_rf build_target_path
    mkdir_p build_target_path
    begin
      with_retries(limit: 5, sleep: 20) do
        sh(ruby.build_command)
        sh("rbenv use #{ruby} && rbenv exec gem install bundler rake --no-ri --no-rdoc")
        sh("tar zcf -C #{build_target_path} #{OUTPUT_DIR}/#{ruby.dest_package_file_name} #{ruby}")
      end
    rescue => e
      $stderr.puts "Failed to build #{ruby} - #{e.message}"
      rubies_that_failed << ruby
    end
  end

  cd OUTPUT_DIR do
    Dir['*.tar.gz'].each do |pkg_file|
      sh("sha256sum #{pkg_file} > #{pkg_file}.sha256")
    end
  end

  if rubies_that_failed.any?
    $stderr.puts "The following rubies failed to build - #{rubies_that_failed.join(', ')}"
    exit(1)
  end

ensure
  rm_rf build_target_path
  mkdir_p build_target_path
end

desc 'verify that all versions can be downloaded from S3'
task :verify_download => [:clean, :init] do
  rubies = rubies_to_build

  rubies.each do |ruby|
    sh("rbenv download #{ruby}")
  end
end
