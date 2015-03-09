require 'rubygems'
require 'rake/clean'

compile_opts = {:CC => '/usr/bin/gcc' }

extra_header_files = %w(debug.h eval_intern.h id.h insns.inc insns_info.inc iseq.h method.h node.h revision.h ruby_atomic.h thread_pthread.h version.h vm_core.h vm_opts.h)

CLEAN.include("downloads")
CLEAN.include("jailed-root")
CLEAN.include("log")
CLEAN.include("pkg")
CLEAN.include("src")

rubies = {
  '1.8.7-p371' => compile_opts.merge(:openssl_patch => true),
  '1.9.2-p320' => compile_opts.merge(:openssl_patch => true),
  '1.9.3-p551' => compile_opts,
  '2.0.0-p353' => compile_opts.merge(:patchsets => true),
  '2.0.0-p598' => compile_opts.merge(:patchsets => true),
  '2.1.0'      => compile_opts,
  '2.1.1'      => compile_opts,
  '2.1.2'      => compile_opts,
  '2.1.3'      => compile_opts,
  '2.1.4'      => compile_opts,
  '2.1.5'      => compile_opts,
  '2.2.0'      => compile_opts,
}

rubies.sort.each do |full_version, opts|
  namespace full_version do
    version, patch = *full_version.split(/-p/)

    prefix = File.join("/opt/local/rbenv/versions", full_version)

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
        url, checksum = %x[curl --fail https://raw.githubusercontent.com/sstephenson/ruby-build/master/share/ruby-build/#{full_version} 2>/dev/null].lines.grep(/ruby-lang.org/).first.gsub('"', '').split[2].split('#')
        ruby_source = File.basename(url)
        sh("curl --fail #{url} > #{ruby_source} 2>/dev/null")
        sh("echo '#{checksum}  #{ruby_source}' > #{ruby_source}.sha2")
        sh("sha256sum --check --status #{ruby_source}.sha2")
      end
    end

    task :configure do
      cd "src" do
        sh("tar -zxf ../downloads/ruby-#{full_version}.tar.gz")
        cd "ruby-#{full_version}" do
          if opts[:patchsets]
            if patch == ''
              sh("set -o pipefail; curl https://raw.githubusercontent.com/skaes/rvm-patchsets/master/patchsets/ruby/#{version}/railsexpress | xargs -I% curl https://raw.githubusercontent.com/skaes/rvm-patchsets/master/patches/ruby/#{version}/% | patch -p1")
            else
              sh("set -o pipefail; curl https://raw.githubusercontent.com/skaes/rvm-patchsets/master/patchsets/ruby/#{version}/p#{patch}/railsexpress | xargs -I% curl https://raw.githubusercontent.com/skaes/rvm-patchsets/master/patches/ruby/#{version}/p#{patch}/% | patch -p1")
            end
          end
          if opts[:openssl_patch]
            patch_command = "patch -p0 < #{File.dirname(File.expand_path(__FILE__))}/patches/ssl_no_ec2m.patch"
            sh(patch_command)
          end

          if File.exists?('bootstraptest/test_io.rb')
            test_io_content = File.read('bootstraptest/test_io.rb')
            test_io_content.gsub!(/^10\.times do.*?end/m, '')

            File.open('bootstraptest/test_io.rb','w') do |f|
              f.puts test_io_content
            end
          end

          gcc_command = opts[:CC] rescue 'gcc'
          sh("CC=#{gcc_command} ./configure --prefix=#{prefix} --enable-shared --enable-rpath --disable-install-doc --disable-install-rdoc > #{File.dirname(__FILE__)}/log/configure.#{full_version}.log 2>&1")
        end
      end
    end

    task :make do
      num_processors = %x[nproc].chomp.to_i
      num_jobs       = num_processors + 1

      cd "src/ruby-#{full_version}" do
        sh("make -j#{num_jobs} > #{File.dirname(__FILE__)}/log/make.#{full_version}.log 2>&1")
        # sh("make test > #{File.dirname(__FILE__)}/log/make.test.#{full_version}.log 2>&1")
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

    task :tar do
      jailed_root = File.join(File.expand_path("../jailed-root", __FILE__))
      mkdir_p "pkg"

      cd jailed_root do
        command = "tar -zcvf  ../pkg/ruby-#{full_version}.tar.gz ."
        sh(command)
      end
    end

    desc "build and package ruby-#{full_version}"
    task :all => [:clean, :init, :download, :configure, :make, :make_install, :tar]
  end

  task :default => "#{full_version}:all"
end

desc "build all rubies"
task :default
