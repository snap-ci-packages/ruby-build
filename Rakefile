require 'rubygems'
require 'bundler/setup'

require 'rake/clean'

distro = nil
fpm_opts = ""

if File.exist?('/etc/system-release') && File.read('/etc/redhat-release') =~ /centos|redhat|fedora|amazon/i
  distro = 'rpm'
  fpm_opts << " --rpm-user root --rpm-group root "
  fpm_opts <<  " --depends 'libyaml-devel' --depends 'openssl-devel' --depends 'readline-devel' "
elsif File.exist?('/etc/os-release') && File.read('/etc/os-release') =~ /ubuntu|debian/i
  distro = 'deb'
  fpm_opts << " --deb-user root --deb-group root "
  fpm_opts << " --depends 'libyaml-dev' --depends 'libssl-dev' --depends 'libreadline-dev' "
end

unless distro
  $stderr.puts "Don't know what distro I'm running on -- not sure if I can build!"
end

extra_header_files = %w(debug.h eval_intern.h id.h insns.inc insns_info.inc iseq.h method.h node.h revision.h ruby_atomic.h thread_pthread.h version.h vm_core.h vm_opts.h)

CLEAN.include("downloads")
CLEAN.include("jailed-root")
CLEAN.include("log")
CLEAN.include("pkg")
CLEAN.include("src")

{
  '1.8.7-p358' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '1.8.7-p371' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '1.9.2-p290' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '1.9.2-p320' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '1.9.3-p194' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '1.9.3-p286' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '1.9.3-p392' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '1.9.3-p484' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '2.0.0-p0'   => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '2.0.0-p195' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '2.0.0-p247' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}},
  '2.0.0-p353' => {:env => {:CC => File.exist?('/etc/debian_version') ? '/usr/bin/gcc-4.4' : '/usr/bin/gcc'}}
}.sort.each do |full_version, opts|
  namespace full_version do
    version, patch = *full_version.split(/-p/)

    prefix = File.join("/opt/local/ruby", full_version)

    CLEAN.include("#{version}/p#{patch}/ruby-#{full_version}")

    task :init do
      mkdir_p "log"
      mkdir_p "pkg"
      mkdir_p "src"
      mkdir_p "downloads"
      mkdir_p "jailed-root"
    end

    task :download do
      cd 'downloads' do
        url, checksum = %x[curl --fail https://raw.github.com/sstephenson/ruby-build/master/share/ruby-build/#{full_version} 2>/dev/null].lines.grep(/ruby-lang.org/).first.gsub('"', '').split[2].split('#')
        ruby_source = File.basename(url)
        sh("curl --fail #{url} > #{ruby_source} 2>/dev/null")
        sh("echo '#{checksum}  #{ruby_source}' > #{ruby_source}.md5")
        sh("md5sum --check --status #{ruby_source}.md5")
      end
    end

    task :configure do
      cd "src" do
        sh("tar -zxf ../downloads/ruby-#{full_version}.tar.gz")
        cd "ruby-#{full_version}" do
          if %w(1.8.7-p358 1.8.7-p371 1.9.2-p290 1.9.2-p320 1.9.3-p194 1.9.3-p286 1.9.3-p392).include?(full_version)
            patch_command = "patch -p0 < #{File.dirname(File.expand_path(__FILE__))}/patches/ssl_no_ec2m.patch"
            sh(patch_command)
          end
          gcc_command = opts[:env][:CC] rescue 'gcc'
          sh("CC=#{gcc_command} ./configure --prefix=#{prefix} --enable-shared --enable-rpath --disable-install-doc --disable-install-rdoc > #{File.dirname(__FILE__)}/log/configure.#{full_version}.log 2>&1")
        end
      end
    end

    task :make do
      num_processors = %x[nproc].chomp.to_i
      num_jobs       = num_processors + 1

      cd "src/ruby-#{full_version}" do
        sh("make -j#{num_jobs} > #{File.dirname(__FILE__)}/log/make.#{full_version}.log 2>&1")
        sh("make test > #{File.dirname(__FILE__)}/log/make.test.#{full_version}.log 2>&1")
      end
    end

    task :make_install do
      jailed_root = File.join(File.expand_path("../jailed-root", __FILE__))
      rm_rf jailed_root
      mkdir_p jailed_root
      cd "src/ruby-#{full_version}" do
        sh("make install DESTDIR=#{jailed_root} > #{File.dirname(__FILE__)}/log/make-install.#{full_version}.log 2>&1")

        if include_dir = Dir["#{jailed_root}/#{prefix}/include/ruby-*/"].first
          Dir["{#{extra_header_files.join(',')}}"].each do |f|
            cp f, include_dir
          end
        end
      end
    end

    task :fpm do
      jailed_root = File.join(File.expand_path("../jailed-root", __FILE__))
      mkdir_p "pkg"

      description_string = %Q{Ruby is the interpreted scripting language for quick and easy object-oriented programming. It has many features to process text files and to do system management tasks, as in Perl. It is simple, straight-forward, extensible, and portable.}

      release = ENV['GO_PIPELINE_COUNTER'] || ENV['RELEASE'] || 1
      cd 'pkg' do
        command = %Q{
          bundle exec fpm -s dir -t #{distro} --name ruby-#{full_version} -a x86_64 --version "#{version}.#{patch}" -C #{jailed_root} --directories #{prefix} --verbose #{fpm_opts} --maintainer snap-ci@thoughtworks.com --vendor snap-ci@thoughtworks.com --url http://snap-ci.com --description "#{description_string}" --iteration #{release} .
        }
        sh(command)
      end
    end

    desc "build and package ruby-#{full_version}"
    task :all => [:clean, :init, :download, :configure, :make, :make_install, :fpm]
  end

  task :default => "#{full_version}:all"
end

desc "build all rubies"
task :default
