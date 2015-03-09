require 'rubygems'
require 'bundler/setup'
require 'snap_ci/parallel_tests'

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

class Ruby
  include Rake::DSL
  attr_reader :full_version, :jailed_root

  def initialize(full_version, jailed_root)
    @full_version = full_version
    @jailed_root = jailed_root
    @full_version.freeze
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

  def apply_patchset?
    true
  end

  def openssl_patch?
    false
  end

  def prefix
    "/opt/local/rbenv/versions/#{full_version}"
  end

  def build_command
    if patch_files.empty?
      "RUBY_BUILD_SKIP_MIRROR=true RUBY_CONFIGURE_OPTS='--disable-install-doc --disable-install-rdoc' src/ruby-build/bin/ruby-build --verbose  #{full_version} #{prefix} > log/ruby-#{full_version}.log 2>&1"
    else
      "cat #{patch_files.join(' ')} | RUBY_BUILD_SKIP_MIRROR=true RUBY_CONFIGURE_OPTS='--disable-install-doc --disable-install-rdoc' src/ruby-build/bin/ruby-build --verbose --patch #{full_version} #{prefix} > log/ruby-#{full_version}.log 2>&1"
    end
  end

  def patch_files
    patch_files = []
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
    "/tmp/ruby-#{full_version}.patch"
  end
end


jailed_root = File.join(File.expand_path('../jailed-root', __FILE__))
output_dir = File.join(File.expand_path('../pkg', __FILE__))

desc 'build all rubies'
task :default => [:clean, :init] do
  all_versions = %x[src/ruby-build/bin/ruby-build --definitions].lines.delete_if { |f| f =~ /rbx|ree|maglev|jruby|mruby|topaz|-rc|-dev|-review/ }.collect { |f| File.basename(f) }.collect(&:chomp)
  versions_to_build = SnapCI::ParallelTests.partition(:things => all_versions)
  $stdout.puts "Here is the list of rubies that will be built on this worker - #{versions_to_build.join(', ')}"
  rubies_to_build = versions_to_build.collect { |v| Ruby.new(v, jailed_root) }.reverse

  rubies_that_failed = []

  rubies_to_build.each do |ruby|
    if only_build_version = ENV['ONLY_BUILD']
      next if only_build_version != ruby.full_version
    end

    $stdout.puts "Building ruby #{ruby.full_version}"

    rm_rf ruby.prefix
    sh(ruby.build_command) do |ok, res|
      if ok
        cd File.dirname(ruby.prefix) do
          sh("tar --owner=root --group=root -zcf #{output_dir}/ruby-#{ruby.full_version}.tar.gz ./#{ruby.full_version}")
        end
      else
        $stderr.puts "Failed to build #{ruby.full_version}"
        rubies_that_failed << ruby
      end
    end
  end

    if rubies_that_failed.any?
      $stderr.puts "The following rubies failed to build - #{rubies_that_failed.collect(&:full_version).join(', ')}"
      exit(1)
    end
end
