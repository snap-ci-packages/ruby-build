require 'rubygems'
require 'bundler/setup'
require 'snap_ci/parallel_tests'
require 'rubygems/version'

compile_opts = { :CC => '/usr/bin/gcc' }

extra_header_files = %w(debug.h eval_intern.h id.h insns.inc insns_info.inc iseq.h method.h node.h revision.h ruby_atomic.h thread_pthread.h version.h vm_core.h vm_opts.h)


task :clean do
  rm_rf 'src'
  rm_rf 'log'
  rm_rf 'pkg'
end

task :init do
  mkdir_p 'src'
  mkdir_p 'log'
  mkdir_p 'pkg'
  sh('git clone --depth 1 --quiet git://github.com/sstephenson/ruby-build.git src/ruby-build')
  sh('git clone --depth 1 --quiet git://github.com/skaes/rvm-patchsets.git src/rvm-patchsets')
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
  attr_reader :full_version, :jailed_root, :type

  def initialize(full_version, jailed_root)
    @full_version = full_version.dup
    if @full_version =~ /jruby/
      @type = 'jruby'
    else
      @type = 'ruby'
    end

    @full_version.gsub!('jruby-', '')
    @full_version.freeze

    @jailed_root = jailed_root
  end

  def jruby?
    @type == 'jruby'
  end

  def version
    full_version.split(/-/).first
  end

  def hyphenated_version
    if full_version =~ /-/
      full_version.split(/-/).last
    end
  end

  def patch_level
    if full_version =~ /-p/
      full_version.split(/-p/).last
    end
  end

  def to_s
    if jruby?
      "jruby-#{full_version}"
    else
      full_version
    end
  end

  def apply_patchset?
    false
  end

  def patches_to_be_applied
    return ['patches/readline.patch'] if version == '2.1.0'
    return ['patches/readline.patch'] if version == '2.1.1'
    return ['patches/readline-2.0.0-p451.patch'] if version == '2.0.0' && patch_level.to_i <= 451
    []
  end

  def prefix
    if jruby?
      "/opt/local/rbenv/versions/jruby-#{full_version}"
    else
      "/opt/local/rbenv/versions/#{full_version}"
    end
  end

  def build_command
    if jruby?
      return "src/ruby-build/bin/ruby-build --verbose #{to_s} #{prefix} > log/#{self}.log 2>&1"
    end
    if patch_files.empty?
      "RUBY_BUILD_SKIP_MIRROR=true RUBY_CONFIGURE_OPTS='--disable-install-doc --disable-install-rdoc' src/ruby-build/bin/ruby-build --verbose #{full_version} #{prefix} > log/#{self}.log 2>&1"
    else
      "cat #{patch_files.join(' ')} | RUBY_BUILD_SKIP_MIRROR=true RUBY_CONFIGURE_OPTS='--disable-install-doc --disable-install-rdoc' src/ruby-build/bin/ruby-build --verbose --patch #{full_version} #{prefix} > log/#{self}.log 2>&1"
    end
  end

  def patch_files
    patch_files = []

    if patches_to_be_applied.any?
      patch_files += patches_to_be_applied
    end

    if apply_patchset?
      if patch_level == nil || patch_level == ''
        patchset_list_file = "src/rvm-patchsets/patchsets/ruby/#{version}/railsexpress"

        if File.exists?(patchset_list_file)
          patch_files = File.read(patchset_list_file).lines.collect(&:chomp)
          patch_files = patch_files.collect { |pf| "src/rvm-patchsets/patches/ruby/#{version}/#{pf}" }
        end
      else
        patchset_list_file = "src/rvm-patchsets/patchsets/ruby/#{version}/p#{patch_level}/railsexpress"

        if File.exists?(patchset_list_file)
          patch_files = File.read(patchset_list_file).lines.collect(&:chomp)
          patch_files = patch_files.collect { |pf| "src/rvm-patchsets/patches/ruby/#{version}/p#{patch_level}/#{pf}" }
        end
      end
      true
    end
    patch_files
  end

  def patch_file
    "/tmp/#{self}.patch"
  end

  def dest_package_file_name
    "#{type}-#{full_version}.tar.gz"
  end
end

jailed_root = File.join(File.expand_path('../jailed-root', __FILE__))
output_dir = File.join(File.expand_path('../pkg', __FILE__))

desc 'build all rubies'
task :default => [:clean, :init] do
  all_versions = %x[src/ruby-build/bin/ruby-build --definitions].lines.delete_if { |f| f =~ /(^1.8.5)|(^1.8.6)|(^1.8.7)|(^1.9.0)|(^1.9.1)|(^1.9.2)|(^1.9.3)|(^2.0.0-p0)|(^2.0.0-p195)|(^2.0.0-p247)|(^jruby-1.5)|(jruby-1.7.7)|(rbx)|(ree)|(maglev)|(mruby)|(topaz)|(-rc)|(-dev)|(-review)|(-preview)|(pre)|(rc)/ }.collect { |f| File.basename(f) }.collect(&:chomp)
  versions_to_build = SnapCI::ParallelTests.partition(:things => all_versions)
  $stdout.puts "Here is the list of rubies that will be built on this worker - #{versions_to_build.join(', ')}"
  rubies_to_build = versions_to_build.collect { |v| Ruby.new(v, jailed_root) }

  rubies_that_failed = []

  rubies_to_build.each do |ruby|
    if only_build_version = ENV['ONLY_BUILD']
      next if only_build_version != ruby.to_s
    end

    $stdout.puts "Building ruby #{ruby}"

    rm_rf ruby.prefix
    begin
      with_retries(limit: 5, sleep: 20) do
        sh(ruby.build_command)
      end

      cd File.dirname(ruby.prefix) do
        with_retries(limit: 5, sleep: 20) do
          [
            "unset GEM_HOME GEM_PATH RUBYOPT BUNDLE_BIN_PATH BUNDLE_GEMFILE; export PATH=#{ruby.prefix}/bin:$PATH; #{ruby.prefix}/bin/gem install bundler --no-ri --no-rdoc",
            "unset GEM_HOME GEM_PATH RUBYOPT BUNDLE_BIN_PATH BUNDLE_GEMFILE; export PATH=#{ruby.prefix}/bin:$PATH; #{ruby.prefix}/bin/gem install rake --force --no-ri --no-rdoc",
            "tar --owner=root --group=root -zcf #{output_dir}/#{ruby.dest_package_file_name} ./#{ruby.to_s}"
          ].each do |cmd|
            sh(cmd)
          end
        end
      end
      $stdout.puts "Built #{ruby} successfully"
    rescue => e
      $stderr.puts "Failed to build #{ruby} - #{e.message}"
      rubies_that_failed << ruby
    end

    rm_rf ruby.prefix
  end

  cd "pkg" do
    Dir['*.tar.gz'].each do |pkg_file|
      sh("sha256sum #{pkg_file} > #{pkg_file}.sha256")
    end
  end

  if rubies_that_failed.any?
    $stderr.puts "The following rubies failed to build - #{rubies_that_failed.join(', ')}"
    exit(1)
  end
end
