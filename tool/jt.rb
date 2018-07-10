#!/usr/bin/env ruby
# encoding: utf-8

# Copyright (c) 2015, 2018 Oracle and/or its affiliates. All rights reserved.
# This code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 1.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

# A workflow tool for TruffleRuby development

# Recommended: function jt { ruby tool/jt.rb "$@"; }

require 'fileutils'
require 'json'
require 'timeout'
require 'yaml'
require 'open3'
require 'rbconfig'
require 'pathname'

TRUFFLERUBY_DIR = File.expand_path('../..', File.realpath(__FILE__))
MRI_TEST_CEXT_DIR = "#{TRUFFLERUBY_DIR}/test/mri/tests/cext-c"
MRI_TEST_CEXT_LIB_DIR = "#{TRUFFLERUBY_DIR}/.ext/c"

TRUFFLERUBY_GEM_TEST_PACK_VERSION = "ac168e3499126c03197d2274f19aa74dfdd90fa6"

JDEBUG_PORT = 51819
JDEBUG = "-J-agentlib:jdwp=transport=dt_socket,server=y,address=#{JDEBUG_PORT},suspend=y"
JEXCEPTION = "-Xexceptions.print_uncaught_java=true"
METRICS_REPS = Integer(ENV["TRUFFLERUBY_METRICS_REPS"] || 10)

RUBOCOP_INCLUDE_LIST = %w[
  lib/cext
  lib/truffle
  src/main/ruby
  src/test/ruby
  test/truffleruby-tool
  tool/generate-sulongmock.rb
]

MAC = RbConfig::CONFIG['host_os'].include?('darwin')
LINUX = RbConfig::CONFIG['host_os'].include?('linux')

SO = MAC ? 'dylib' : 'so'

# Expand GEM_HOME relative to cwd so it cannot be misinterpreted later.
ENV['GEM_HOME'] = File.expand_path(ENV['GEM_HOME']) if ENV['GEM_HOME']

require "#{TRUFFLERUBY_DIR}/lib/truffle/truffle/openssl-prefix.rb"

# wait for sub-processes to handle the interrupt
trap(:INT) {}

module Utilities
  def self.truffle_version
    suite = File.read("#{TRUFFLERUBY_DIR}/mx.truffleruby/suite.py")
    raise unless /"name": "tools",.+?"version": "(\h{40})"/m =~ suite
    $1
  end

  def self.jvmci_version
    if env = ENV["JVMCI_VERSION"]
      unless /8u(\d+)-(jvmci-0.\d+)/ =~ env
        raise "Could not parse JDK update and JVMCI version from $JVMCI_VERSION"
      end
    else
      ci = File.read("#{TRUFFLERUBY_DIR}/ci.jsonnet")
      unless /JAVA_HOME: \{\n\s*name: "labsjdk",\n\s*version: "8u(\d+)-(jvmci-0.\d+)",/ =~ ci
        raise "JVMCI version not found in ci.jsonnet: #{ci[0, 1000]}"
      end
    end
    update, jvmci = $1, $2
    [update, jvmci]
  end

  def self.find_graal_javacmd_and_options
    graalvm = ENV['GRAALVM_BIN']
    jvmci = ENV['JVMCI_BIN']
    graal_home = ENV['GRAAL_HOME']

    raise "More than one of GRAALVM_BIN, JVMCI_BIN or GRAAL_HOME defined!" if [graalvm, jvmci, graal_home].compact.count > 1

    if graalvm
      javacmd = File.expand_path(graalvm, TRUFFLERUBY_DIR)
      vm_args = []
      options = []
    elsif jvmci
      javacmd = File.expand_path(jvmci, TRUFFLERUBY_DIR)
      jvmci_graal_home = ENV['JVMCI_GRAAL_HOME']
      raise "Also set JVMCI_GRAAL_HOME if you set JVMCI_BIN" unless jvmci_graal_home
      jvmci_graal_home = File.expand_path(jvmci_graal_home, TRUFFLERUBY_DIR)
      vm_args = [
        '-d64',
        '-XX:+UnlockExperimentalVMOptions',
        '-XX:+EnableJVMCI',
        '--add-exports=java.base/jdk.internal.module=com.oracle.graal.graal_core',
        "--module-path=#{jvmci_graal_home}/../truffle/mxbuild/modules/com.oracle.truffle.truffle_api.jar:#{jvmci_graal_home}/mxbuild/modules/com.oracle.graal.graal_core.jar"
      ]
      options = ['--no-bootclasspath']
    elsif graal_home
      graal_home = File.expand_path(graal_home, TRUFFLERUBY_DIR)
      output, _ = ShellUtils.mx('-v', '-p', graal_home, 'vm', '-version', :err => :out, capture: true)
      command_line = output.lines.select { |line| line.include? '-version' }
      if command_line.size == 1
        command_line = command_line[0]
      else
        $stderr.puts "Error in mx for setting up Graal:"
        $stderr.puts output
        abort
      end
      vm_args = command_line.split
      vm_args.pop # Drop "-version"
      javacmd = vm_args.shift
      options = []
    elsif graal_home = find_auto_graal_home
      javacmd = "#{find_graal_java_home(graal_home)}/bin/java"
      graal_jars = [
        "#{graal_home}/mxbuild/dists/graal.jar",
        "#{graal_home}/mxbuild/dists/graal-management.jar"
      ]
      vm_args = [
        '-XX:+UnlockExperimentalVMOptions',
        '-XX:+EnableJVMCI',
        "-Djvmci.class.path.append=#{graal_jars.join(':')}",
        # No -Xbootclasspath for sdk & Truffle, it's already added by the normal launcher
      ]
      options = []
    else
      raise 'set one of GRAALVM_BIN or GRAAL_HOME in order to use Graal'
    end
    [javacmd, vm_args.map { |arg| "-J#{arg}" } + options]
  end

  def self.find_auto_graal_home
    sibling_compiler = File.expand_path('../graal/compiler', TRUFFLERUBY_DIR)
    return nil unless Dir.exist?(sibling_compiler)
    return nil unless File.exist?("#{sibling_compiler}/mxbuild/dists/graal-compiler.jar")
    sibling_compiler
  end

  def self.find_graal_java_home(graal_home)
    env_file = "#{graal_home}/mx.compiler/env"
    graal_env = File.exist?(env_file) ? File.read(env_file) : ""
    if java_home = graal_env[/^JAVA_HOME=(.+)$/, 1]
      java_home
    else
      ENV.fetch("JAVA_HOME") { raise "Could not find JAVA_HOME of graal in #{env_file} or in ENV" }
    end
  end

  def self.which(binary)
    ENV["PATH"].split(File::PATH_SEPARATOR).each do |dir|
      path = "#{dir}/#{binary}"
      return path if File.executable? path
    end
    nil
  end

  def self.find_mx
    if which('mx')
      'mx'
    else
      mx_repo = find_or_clone_repo("https://github.com/graalvm/mx.git")
      "#{mx_repo}/mx"
    end
  end

  def self.find_launcher(use_native)
    if use_native
      ENV['AOT_BIN'] || "#{TRUFFLERUBY_DIR}/bin/native-ruby"
    else
      ENV['RUBY_BIN'] || "#{TRUFFLERUBY_DIR}/bin/truffleruby"
    end
  end

  def self.find_repo(name)
    [TRUFFLERUBY_DIR, "#{TRUFFLERUBY_DIR}/.."].each do |dir|
      found = Dir.glob("#{dir}/#{name}*").sort.first
      return File.expand_path(found) if found
    end
    raise "Can't find the #{name} repo - clone it into the repository directory or its parent"
  end

  def self.find_or_clone_repo(url, commit=nil)
    name = File.basename url, '.git'
    path = File.expand_path("../#{name}", TRUFFLERUBY_DIR)
    unless Dir.exist? path
      target = "../#{name}"
      ShellUtils.sh "git", "clone", url, target
      ShellUtils.sh "git", "checkout", commit, chdir: target if commit
    end
    path
  end

  def self.find_benchmark(benchmark)
    if File.exist?(benchmark)
      benchmark
    else
      File.join(TRUFFLERUBY_DIR, 'bench', benchmark)
    end
  end

  def self.find_gem(name)
    ["#{TRUFFLERUBY_DIR}/lib/ruby/gems/shared/gems"].each do |dir|
      found = Dir.glob("#{dir}/#{name}*").sort.first
      return File.expand_path(found) if found
    end

    [TRUFFLERUBY_DIR, "#{TRUFFLERUBY_DIR}/.."].each do |dir|
      found = Dir.glob("#{dir}/#{name}").sort.first
      return File.expand_path(found) if found
    end
    raise "Can't find the #{name} gem - gem install it in this repository, or put it in the repository directory or its parent"
  end

  def self.git_branch
    @git_branch ||= `GIT_DIR="#{TRUFFLERUBY_DIR}/.git" git rev-parse --abbrev-ref HEAD`.strip
  end

  def self.igv_running?
    `ps ax`.include?('idealgraphvisualizer')
  end

  def self.no_gem_vars_env
    {
      'TRUFFLERUBY_RESILIENT_GEM_HOME' => nil,
      'GEM_HOME' => nil,
      'GEM_PATH' => nil,
      'GEM_ROOT' => nil,
    }
  end

  def self.human_size(bytes)
    if bytes < 1024
      "#{bytes} B"
    elsif bytes < 1000**2
      "#{(bytes/1024.0).round(2)} KB"
    elsif bytes < 1000**3
      "#{(bytes/1024.0**2).round(2)} MB"
    elsif bytes < 1000**4
      "#{(bytes/1024.0**3).round(2)} GB"
    else
      "#{(bytes/1024.0**4).round(2)} TB"
    end
  end

  def self.log(tty_message, full_message)
    if STDERR.tty?
      STDERR.print tty_message unless tty_message.nil?
    else
      STDERR.print full_message unless full_message.nil?
    end
  end

  def self.diff(expected, actual)
    `diff -u #{expected} #{actual}`
  end

end

module ShellUtils
  module_function

  def system_timeout(timeout, *args)
    begin
      pid = Process.spawn(*args)
    rescue SystemCallError
      return nil
    end

    begin
      Timeout.timeout timeout do
        Process.waitpid pid
        $?.success?
      end
    rescue Timeout::Error
      Process.kill('TERM', pid)
      Process.waitpid pid
      nil
    end
  end

  def raw_sh(*args)
    options = args.last.is_a?(Hash) ? args.last : {}
    continue_on_failure = options.delete :continue_on_failure
    use_exec = options.delete :use_exec
    timeout = options.delete :timeout
    capture = options.delete :capture

    unless options.delete :no_print_cmd
      STDERR.puts "$ #{printable_cmd(args)}"
    end

    if use_exec
      result = exec(*args)
    elsif timeout
      result = system_timeout(timeout, *args)
    elsif capture
      out, err, status = Open3.capture3(*args)
      result = status.success?
    else
      result = system(*args)
    end

    if result
      if capture
        [out, err]
      else
        true
      end
    elsif continue_on_failure
      false
    else
      status = $? unless capture
      $stderr.puts "FAILED (#{status}): #{printable_cmd(args)}"

      if capture
        $stderr.puts out
        $stderr.puts err
      end

      if status && status.exitstatus
        exit status.exitstatus
      else
        exit 1
      end
    end
  end

  def printable_cmd(args)
    env = {}
    if Hash === args.first
      env, *args = args
    end
    if Hash === args.last && args.last.empty?
      *args, options = args
    end
    env = env.map { |k,v| "#{k}=#{shellescape(v)}" }.join(' ')
    args = args.map { |a| shellescape(a) }.join(' ')
    env.empty? ? args : "#{env} #{args}"
  end

  def shellescape(str)
    return str unless str.is_a?(String)
    if str.include?(' ')
      if str.include?("'")
        require 'shellwords'
        Shellwords.escape(str)
      else
        "'#{str}'"
      end
    else
      str
    end
  end

  def replace_env_vars(string, env = ENV)
    string.gsub(/\$([A-Z_]+)/) {
      var = $1
      abort "You need to set $#{var}" unless env[var]
      env[var]
    }
  end

  def sh(*args)
    chdir(TRUFFLERUBY_DIR) do
      raw_sh(*args)
    end
  end

  def chdir(dir, &block)
    raise LocalJumpError, "no block given" unless block_given?
    if dir == Dir.pwd
      yield
    else
      STDERR.puts "$ cd #{dir}"
      ret = Dir.chdir(dir, &block)
      STDERR.puts "$ cd #{Dir.pwd}"
      ret
    end
  end

  def mx(*args, java_home: nil, **kwargs)
    mx_args = args
    mx_args.unshift '--java-home', java_home if java_home
    raw_sh Utilities.find_mx, *mx_args, **kwargs
  end

  def mspec(command, *args)
    env_vars = {}
    if command.is_a?(Hash)
      env_vars = command
      command, *args = args
    end

    mspec_args = ['spec/mspec/bin/mspec', command, '--config', 'spec/truffle.mspec', *args]

    if i = args.index('-t')
      launcher = args[i+1]
      flags = args.select { |arg| arg.start_with?('-T') }.map { |arg| arg[2..-1] }
      sh env_vars, launcher, *flags, *mspec_args, use_exec: true
    else
      ruby env_vars, *mspec_args
    end
  end

  def newer?(input, output)
    return true unless File.exist? output
    File.mtime(input) > File.mtime(output)
  end
end

module Commands
  include ShellUtils

  def help
    puts <<-TXT.gsub(/^#{' '*6}/, '')
      jt build [options]                             build
          parser                                     build the parser
          options                                    build the options
          cexts                                      build only the C extensions (part of "jt build")
          native [--no-sulong] [--no-jvmci] [--no-sforceimports] [--no-tools] [extra mx image options]
                                                     build a native image of TruffleRuby (--no-jvmci to use the system Java) 
                                                     (--no-tools to exclude chromeinspector and profiler)
      jt build_stats [--json] <attribute>            prints attribute's value from build process (e.g., binary size)
      jt clean                                       clean
      jt env                                         prints the current environment
      jt rebuild                                     clean, sforceimports, and build
      jt dis <file>                                  finds the bc file in the project, disassembles, and returns new filename
      jt ruby [options] args...                      run TruffleRuby with args
          --graal         use Graal (set either GRAALVM_BIN, JVMCI_BIN or GRAAL_HOME, or have graal built as a sibling)
              --stress    stress the compiler (compile immediately, foreground compilation, compilation exceptions are fatal)
          --asm           show assembly (implies --graal)
          --server        run an instrumentation server on port 8080
          --igv           make sure IGV is running and dump Graal graphs after partial escape (implies --graal)
              --full      show all phases, not just up to the Truffle partial escape
          --infopoints    show source location for each node in IGV
          --fg            disable background compilation
          --trace         show compilation information on stdout
          --jdebug        run a JDWP debug server on #{JDEBUG_PORT}
          --jexception[s] print java exceptions
          --exec          use exec rather than system
          --no-print-cmd  don\'t print the command
      jt e 14 + 2                                    evaluate an expression
      jt puts 14 + 2                                 evaluate and print an expression
      jt cextc directory clang-args                  compile the C extension in directory, with optional extra clang arguments
      jt test                                        run all mri tests, specs and integration tests
      jt test mri                                    run mri tests
          --cext          runs MRI C extension tests
          --syslog        runs syslog tests
          --openssl       runs openssl tests
          --native        use native TruffleRuby image (set AOT_BIN)
          --graal         use Graal (set either GRAALVM_BIN, JVMCI_BIN or GRAAL_HOME, or have graal built as a sibling)
      jt test mri test/mri/tests/test_find.rb [-- <MRI runner options>]
                                                     run tests in given file, -n option of the runner can be used to further
                                                     limit executed test methods
      jt test specs                                  run all specs
      jt test specs fast                             run all specs except sub-processes, GC, sleep, ...
      jt test spec/ruby/language                     run specs in this directory
      jt test spec/ruby/language/while_spec.rb       run specs in this file
      jt test compiler                               run compiler tests (uses the same logic as --graal to find Graal)
      jt test integration                            runs all integration tests
      jt test integration [TESTS]                    runs the given integration tests
      jt test bundle [--jdebug]                      tests using bundler
      jt test gems                                   tests using gems
      jt test ecosystem [TESTS]                      tests using the wider ecosystem such as bundler, Rails, etc
      jt test cexts [--no-openssl] [--no-gems] [test_names...]
                                                     run C extension tests (set GEM_HOME)
      jt test report :language                       build a report on language specs
                     :core                               (results go into test/target/mspec-html-report)
                     :library
      jt gem-test-pack                               check that the gem test pack is downloaded, or download it for you, and print the path
      jt rubocop [rubocop options]                   run rubocop rules (using ruby available in the environment)
      jt tag spec/ruby/language                      tag failing specs in this directory
      jt tag spec/ruby/language/while_spec.rb        tag failing specs in this file
      jt tag all spec/ruby/language                  tag all specs in this file, without running them
      jt untag spec/ruby/language                    untag passing specs in this directory
      jt untag spec/ruby/language/while_spec.rb      untag passing specs in this file
      jt mspec ...                                   run MSpec with the TruffleRuby configuration and custom arguments
      jt metrics alloc [--json] ...                  how much memory is allocated running a program
      jt metrics instructions ...                    how many CPU instructions are used to run a program
      jt metrics minheap ...                         what is the smallest heap you can use to run an application
      jt metrics time ...                            how long does it take to run a command, broken down into different phases
      jt benchmark [options] args...                 run benchmark-interface (implies --graal)
          --no-graal              don't imply --graal
          JT_BENCHMARK_RUBY=ruby  benchmark some other Ruby, like MRI
          note that to run most MRI benchmarks, you should translate them first with normal Ruby and cache the result, such as
              benchmark bench/mri/bm_vm1_not.rb --cache
              jt benchmark bench/mri/bm_vm1_not.rb --use-cache
      jt where repos ...                            find these repositories
      jt next                                       tell you what to work on next (give you a random core library spec)
      jt pr [pr_number]                             pushes GitHub's PR to bitbucket to let CI run under github/pr/<number> name
                                                    if the pr_number is not supplied current HEAD is used to find a PR which contains it
      jt pr clean [--dry-run]                       delete all github/pr/<number> branches from BB whose GitHub PRs are closed
      jt install jvmci                              install a JVMCI JDK in the parent directory
      jt install graal [--no-jvmci]                 install Graal in the parent directory (--no-jvmci to use the system Java)
      jt docker                                     build a Docker image - see doc/contributor/docker.md

      you can also put --build or --rebuild in front of any command to build or rebuild first

      recognised environment variables:

        RUBY_BIN                                     The TruffleRuby executable to use (normally just bin/truffleruby)
        GRAALVM_BIN                                  GraalVM executable (java command)
        GRAAL_HOME                                   Directory where there is a built checkout of the Graal compiler (make sure mx is on your path)
        JVMCI_BIN                                    JVMCI-enabled java command (also set JVMCI_GRAAL_HOME)
        JVMCI_GRAAL_HOME                             Like GRAAL_HOME, but only used for the JARs to run with JVMCI_BIN
        OPENSSL_PREFIX                               Where to find OpenSSL headers and libraries
        AOT_BIN                                      TruffleRuby/SVM executable
    TXT
  end

  def mx(*args)
    super(*args)
  end

  def build(*options)
    project = options.shift
    case project
    when 'parser'
      jay = Utilities.find_or_clone_repo('https://github.com/jruby/jay.git', '9ffc59aabf21bee1737836fe972c4bd51f41049e')
      raw_sh 'make', chdir: "#{jay}/src"
      ENV['PATH'] = "#{jay}/src:#{ENV['PATH']}"
      sh 'bash', 'tool/generate_parser'
      yytables = 'src/main/java/org/truffleruby/parser/parser/YyTables.java'
      File.write(yytables, File.read(yytables).gsub('package org.jruby.parser;', 'package org.truffleruby.parser.parser;'))
    when 'options'
      sh 'tool/generate-options.rb'
    when "cexts" # Included in 'mx build' but useful to recompile just that part
      require 'etc'
      cores = Etc.respond_to?(:nprocessors) ? Etc.nprocessors : 4
      raw_sh "make", "-j#{cores}", chdir: "#{TRUFFLERUBY_DIR}/src/main/c"
    when 'native'
      build_native_image *options
    when nil
      build_truffleruby
    else
      raise ArgumentError, project
    end
  end

  def build_truffleruby(*options, sforceimports: true)
    mx 'sforceimports' if sforceimports

    mx 'build', '--force-javac', '--warning-as-error', '--force-deprecation-as-warning',
       # show more than default 100 errors not to hide actual errors under pile of missing symbols
       '-A-Xmaxerrs', '-A1000', *options
  end

  def clean(*options)
    project = options.shift
    case project
    when 'cexts'
      raw_sh "make", "clean", chdir: "#{TRUFFLERUBY_DIR}/src/main/c"
    when nil
      mx 'clean'
      sh 'rm', '-rf', 'mxbuild'
      sh 'rm', '-rf', 'spec/ruby/ext'
    else
      raise ArgumentError, project
    end
  end

  def dis(file)
    dis = `which llvm-dis-3.8 llvm-dis 2>/dev/null`.lines.first.chomp
    file = `find #{TRUFFLERUBY_DIR} -name "#{file}"`.lines.first.chomp
    raise ArgumentError, "file not found:`#{file}`" if file.empty?
    sh dis, file
    puts Pathname(file).sub_ext('.ll')
  end

  def env
    puts "Environment"
    env_vars = %w[JAVA_HOME PATH RUBY_BIN GRAALVM_BIN
                  GRAAL_HOME TRUFFLERUBY_RESILIENT_GEM_HOME
                  JVMCI_BIN JVMCI_GRAAL_HOME OPENSSL_PREFIX
                  AOT_BIN TRUFFLERUBY_CEXT_ENABLED
                  TRUFFLERUBYOPT RUBYOPT]
    column_size = env_vars.map(&:size).max
    env_vars.each do |e|
      puts format "%#{column_size}s: %s", e, ENV[e].inspect
    end
    shell = -> command { raw_sh(*command.split, continue_on_failure: true) }
    shell['ruby -v']
    shell['uname -a']
    shell['cc -v']
    shell['gcc -v']
    shell['clang -v']
    shell['opt -version']
    shell['/usr/local/opt/llvm@4/bin/clang -v']
    shell['/usr/local/opt/llvm@4/bin/opt -version']
    shell['mx version']
    sh('mx', 'sversions', continue_on_failure: true)
    shell['git --no-pager show -s --format=%H']
    if ENV['OPENSSL_PREFIX']
      shell["#{ENV['OPENSSL_PREFIX']}/bin/openssl version"]
    else
      shell["openssl version"]
    end
    shell['java -version']
  end

  def rebuild(*options)
    clean(*options)
    build(*options)
  end

  def run_ruby(*args)
    env_vars = args.first.is_a?(Hash) ? args.shift : {}
    options = args.last.is_a?(Hash) ? args.pop : {}
    native = args.delete('--native')

    vm_args = []

    {
      '--asm' => '--graal',
      '--stress' => '--graal',
      '--igv' => '--graal',
      '--trace' => '--graal',
    }.each_pair do |arg, dep|
      args.unshift dep if args.include?(arg)
    end

    unless args.delete('--no-core-load-path')
      vm_args << "-Xcore.load_path=#{TRUFFLERUBY_DIR}/src/main/ruby"
    end

    if args.delete('--graal')
      if ENV["RUBY_BIN"] || native
        # Assume that Graal is automatically set up if RUBY_BIN is set or using a native image.
      else
        javacmd, javacmd_options = Utilities.find_graal_javacmd_and_options
        env_vars["JAVACMD"] = javacmd
        vm_args.push(*javacmd_options)
      end
    end

    if args.delete('--stress')
      vm_args << '-J-Dgraal.TruffleCompileImmediately=true'
      vm_args << '-J-Dgraal.TruffleBackgroundCompilation=false'
      vm_args << '-J-Dgraal.TruffleCompilationExceptionsAreFatal=true'
    end

    if args.delete('--asm')
      vm_args += %w[-J-XX:+UnlockDiagnosticVMOptions -J-XX:CompileCommand=print,*::callRoot]
    end

    if args.delete('--jdebug')
      vm_args << JDEBUG
    end

    if args.delete('--jexception') || args.delete('--jexceptions')
      vm_args << JEXCEPTION
    end

    if args.delete('--server')
      vm_args += %w[-Xinstrumentation_server_port=8080]
    end

    if args.delete('--igv')
      if args.delete('--full')
        vm_args << "-J-Dgraal.Dump=:2"
      else
        vm_args << "-J-Dgraal.Dump=TruffleTree,PartialEscape:2"
      end
      vm_args << "-J-Dgraal.PrintGraphFile=true" unless Utilities.igv_running?
      vm_args << "-J-Dgraal.PrintBackendCFG=false"
    end

    if args.delete('--infopoints')
      vm_args << "-J-XX:+UnlockDiagnosticVMOptions" << "-J-XX:+DebugNonSafepoints"
      vm_args << "-J-Dgraal.TruffleEnableInfopoints=true"
    end

    if args.delete('--fg')
      vm_args << "-J-Dgraal.TruffleBackgroundCompilation=false"
    end

    if args.delete('--trace')
      vm_args << "-J-Dgraal.TraceTruffleCompilation=true"
    end

    if args.delete('--no-print-cmd')
      options[:no_print_cmd] = true
    end

    if args.delete('--exec')
      options[:use_exec] = true
    end

    ruby_bin = Utilities.find_launcher(native)

    raw_sh env_vars, ruby_bin, *vm_args, *args, options
  end
  private :run_ruby

  # Same as #run but uses exec()
  def ruby(*args)
    run_ruby(*args, '--exec')
  end

  # Legacy alias
  alias_method :run, :ruby

  def e(*args)
    ruby '-e', args.join(' ')
  end

  def command_puts(*args)
    e 'puts begin', *args, 'end'
  end

  def command_p(*args)
    e 'p begin', *args, 'end'
  end

  # Just convenience
  def gem(*args)
    ruby '-S', 'gem', *args
  end

  def cextc(cext_dir, *clang_opts)
    cext_dir = File.expand_path(cext_dir)
    name = File.basename(cext_dir)
    ext_dir = "#{cext_dir}/ext/#{name}"
    target = "#{cext_dir}/lib/#{name}/#{name}.su"
    compile_cext(name, ext_dir, target, *clang_opts)
  end

  def compile_cext(name, ext_dir, target, *clang_opts)
    extconf = "#{ext_dir}/extconf.rb"
    raise "#{extconf} does not exist" unless File.exist?(extconf)

    # Make sure ruby.su is built
    build("cexts")

    chdir(ext_dir) do
      run_ruby('-rmkmf', "#{ext_dir}/extconf.rb") # -rmkmf is required for C ext tests
      if File.exists?('Makefile')
        raw_sh("make")
        FileUtils::Verbose.cp("#{name}.su", target) if target
      else
        STDERR.puts "Makefile not found in #{ext_dir}, skipping make."
      end
    end
  end

  module PR
    include ShellUtils
    extend self

    def pr_clean(*args)
      require 'net/http'

      dry_run = args.delete '--dry-run'
      uri     = URI('https://api.github.com/repos/oracle/truffleruby/pulls')
      puts "Contacting GitHub: #{uri}"
      data     = Net::HTTP.get(uri)
      prs_data = JSON.parse data
      open_prs = prs_data.map { |prd| Integer(prd.fetch('number')) }
      puts "Open PRs: #{open_prs}"

      sh 'git', 'fetch', Remotes.bitbucket, '--prune' # ensure we have locally only existing remote branches
      branches, _        = sh 'git', 'branch', '--remote', '--list', capture: true
      branches_to_delete = branches.
          scan(/^ *#{Remotes.bitbucket}\/(github\/pr\/(\d+))$/).
          reject { |_, number| open_prs.include? Integer(number) }

      puts "Deleting #{branches_to_delete.size} remote branches on #{Remotes.bitbucket}:"
      puts branches_to_delete.map(&:last).map(&:to_i).to_s
      return if dry_run

      branches_to_delete.each do |remote_branch, _|
        sh 'git', 'push', '--no-verify', Remotes.bitbucket, ":#{remote_branch}"
      end

      # update remote branches
      sh 'git', 'fetch', Remotes.bitbucket, '--prune'
    end

    def pr_push(*args)
      # Fetch PRs on GitHub
      fetch     = "+refs/pull/*/head:refs/remotes/#{Remotes.github}/pr/*"
      out, _err = sh 'git', 'config', '--get-all', "remote.#{Remotes.github}.fetch", capture: true
      sh 'git', 'config', '--add', "remote.#{Remotes.github}.fetch", fetch unless out.include? fetch
      sh 'git', 'fetch', Remotes.github

      pr_number = args.first
      if pr_number
        github_pr_branch = "#{Remotes.github}/pr/#{pr_number}"
      else
        github_pr_branch = begin
          out, _err = sh 'git', 'branch', '-r', '--contains', 'HEAD', capture: true
          candidate = out.lines.find { |l| l.strip.start_with? "#{Remotes.github}/pr/" }
          candidate && candidate.strip.chomp
        end

        unless github_pr_branch
          puts 'Could not find HEAD in any of the GitHub pull-requests.'
          exit 1
        end

        pr_number = github_pr_branch.split('/').last
      end

      target_branch = if Utilities.git_branch.start_with?('release')
        Utilities.git_branch
      else
        "github/pr/#{pr_number}"
      end

      sh 'git', 'push', '--force', '--no-verify', Remotes.bitbucket, "#{github_pr_branch}:refs/heads/#{target_branch}"
    end

    def pr_update_master(skip_upstream_fetch: false)
      sh 'git', 'fetch', Remotes.github unless skip_upstream_fetch
      sh 'git', 'push', '--no-verify', Remotes.bitbucket, "#{Remotes.github}/master:master"
    end
  end

  module Remotes
    include ShellUtils
    extend self

    def bitbucket(dir = TRUFFLERUBY_DIR)
      candidate = remote_urls(dir).find { |r, u| u.include? 'ol-bitbucket' }
      candidate.first if candidate
    end

    def github(dir = TRUFFLERUBY_DIR)
      candidate = remote_urls(dir).find { |r, u| u.match %r(github.com[:/]oracle) }
      candidate.first if candidate
    end

    def remote_urls(dir = TRUFFLERUBY_DIR)
      @remote_urls ||= Hash.new
      @remote_urls[dir] ||= begin
        out, _err = raw_sh 'git', '-C', dir, 'remote', capture: true, no_print_cmd: true
        out.split.map do |remote|
          url, _err = raw_sh 'git', '-C', dir, 'config', '--get', "remote.#{remote}.url", capture: true, no_print_cmd: true
          [remote, url.chomp]
        end
      end
    end

    def try_fetch(repo)
      remote = github(repo) || bitbucket(repo) || 'origin'
      raw_sh "git", "-C", repo, "fetch", remote, continue_on_failure: true
    end
  end

  def pr(*args)
    command, *options = args
    case command
    when 'clean'
      PR.pr_clean *options
    when 'up'
      PR.pr_update_master *options
    else
      PR.pr_push *args
      # To regularly update bb/master
      PR.pr_update_master skip_upstream_fetch: true
    end
  end

  def test(*args)
    path, *rest = args

    case path
    when nil
      ENV['HAS_REDIS'] = 'true'
      %w[specs mri bundle cexts integration gems ecosystem compiler].each do |kind|
        jt('test', kind)
      end
    when 'bundle' then test_bundle(*rest)
    when 'compiler' then test_compiler(*rest)
    when 'cexts' then test_cexts(*rest)
    when 'report' then test_report(*rest)
    when 'integration' then test_integration(*rest)
    when 'gems' then test_gems(*rest)
    when 'ecosystem' then test_ecosystem(*rest)
    when 'specs' then test_specs('run', *rest)
    when 'mri' then test_mri(*rest)
    else
      if File.expand_path(path, TRUFFLERUBY_DIR).start_with?("#{TRUFFLERUBY_DIR}/test")
        test_mri(*args)
      else
        test_specs('run', *args)
      end
    end
  end

  def jt(*args)
    sh RbConfig.ruby, 'tool/jt.rb', *args
  end
  private :jt

  def test_mri(*args)
    double_dash_index = args.index '--'
    if double_dash_index
      runner_args = args[(double_dash_index + 1)..-1]
      args        = args[0...double_dash_index]
    else
      runner_args = []
    end

    if args.delete('--openssl')
      include_pattern = "#{TRUFFLERUBY_DIR}/test/mri/tests/openssl/test_*.rb"
      exclude_file = "#{TRUFFLERUBY_DIR}/test/mri/openssl.exclude"
    elsif args.delete('--syslog')
      include_pattern = ["#{TRUFFLERUBY_DIR}/test/mri/tests/test_syslog.rb",
                         "#{TRUFFLERUBY_DIR}/test/mri/tests/syslog/test_syslog_logger.rb"]
      exclude_file = nil
    elsif args.delete('--cext')
      include_pattern = "#{TRUFFLERUBY_DIR}/test/mri/tests/cext-ruby/**/test_*.rb"
      exclude_file = "#{TRUFFLERUBY_DIR}/test/mri/cext.exclude"
    elsif args.all? { |a| a.start_with?('-') }
      include_pattern = "#{TRUFFLERUBY_DIR}/test/mri/tests/**/test_*.rb"
      exclude_file = "#{TRUFFLERUBY_DIR}/test/mri/standard.exclude"
    else
      args, files_to_run = args.partition { |a| a.start_with?('-') }
    end

    unless files_to_run
      prefix = "#{TRUFFLERUBY_DIR}/test/mri/tests/"
      include_files = Dir.glob(include_pattern).map { |f|
        raise unless f.start_with?(prefix)
        f[prefix.size..-1]
      }

      include_files.reject! { |f| f.include?('cext-ruby') } unless include_pattern.include?('cext-ruby')

      exclude_files = if exclude_file
                        File.readlines(exclude_file).map { |l| l.gsub(/#.*/, '').strip }
                      else
                        []
                      end

      files_to_run = (include_files - exclude_files)
    end

    files_to_run.sort!

    run_mri_tests(args, files_to_run, runner_args)
  end
  private :test_mri

  def run_mri_tests(extra_args, test_files, runner_args, run_options = {})
    prefix = "test/mri/tests/"
    abs_prefix = "#{TRUFFLERUBY_DIR}/#{prefix}"
    test_files = test_files.map { |file|
      if file.start_with?(prefix)
        file[prefix.size..-1]
      elsif file.start_with?(abs_prefix)
        file[abs_prefix.size..-1]
      else
        file
      end
    }

    truffle_args =  if extra_args.include?('--native')
                      %W[-Xhome=#{TRUFFLERUBY_DIR}]
                    else
                      %w[-J-Xmx2G -J-ea -J-esa --jexceptions]
                    end

    env_vars = {
      "EXCLUDES" => "test/mri/excludes",
      "RUBYOPT" => '--disable-gems',
      "TRUFFLERUBY_RESILIENT_GEM_HOME" => nil,
    }

    cext_tests = test_files.select { |f| f.include?("cext-ruby") }
    cext_tests.each do |test|
      puts
      puts test
      test_path = "#{TRUFFLERUBY_DIR}/test/mri/tests/#{test}"
      match = File.read(test_path).match(/\brequire ['"]c\/(.*?)["']/)
      if match
        cext_name = match[1]
        compile_dir = if cext_name.include?('/')
                        if Dir.exists?("#{MRI_TEST_CEXT_DIR}/#{cext_name}")
                          "#{MRI_TEST_CEXT_DIR}/#{cext_name}"
                        else
                          "#{MRI_TEST_CEXT_DIR}/#{File.dirname(cext_name)}"
                        end
                      else
                        if Dir.exists?("#{MRI_TEST_CEXT_DIR}/#{cext_name}")
                          "#{MRI_TEST_CEXT_DIR}/#{cext_name}"
                        else
                          "#{MRI_TEST_CEXT_DIR}/#{cext_name.gsub('_', '-')}"
                        end
                      end
        name = File.basename(match[1])
        target_dir = if match[1].include?('/')
                       File.dirname(match[1])
                     else
                       ''
                     end
        dest_dir = File.join(MRI_TEST_CEXT_LIB_DIR, target_dir)
        FileUtils::Verbose.mkdir_p(dest_dir)
        compile_cext(name, compile_dir, dest_dir)
      else
        puts "c require not found for cext test: #{test_path}"
      end
    end

    command = %w[test/mri/tests/runner.rb -v --color=never --tty=no -q]
    command.unshift("-I#{TRUFFLERUBY_DIR}/.ext")  if !cext_tests.empty?
    run_ruby(env_vars, *truffle_args, *extra_args, *command, *test_files, *runner_args, run_options)
  end
  private :run_mri_tests

  def retag(*args)
    options, test_files = args.partition { |a| a.start_with?('-') }
    raise unless test_files.size == 1
    test_file = test_files[0]
    test_classes = File.read(test_file).scan(/class ([\w:]+) < .+TestCase/)
    test_classes.each do |test_class,|
      prefix = "test/mri/excludes/#{test_class.gsub('::', '/')}"
      FileUtils::Verbose.rm_f "#{prefix}.rb"
      FileUtils::Verbose.rm_rf prefix
    end

    puts "1. Tagging tests"
    output_file = "mri_tests.txt"
    run_mri_tests(options, test_files, [], out: output_file, continue_on_failure: true)

    puts "2. Parsing errors"
    sh "ruby", "tool/parse_mri_errors.rb", output_file

    puts "3. Verifying tests pass"
    run_mri_tests(options, test_files, [])
  end

  def test_compiler(*args)
    env = {}

    env['TRUFFLERUBYOPT'] = '-Xexceptions.print_java=true'

    Dir["#{TRUFFLERUBY_DIR}/test/truffle/compiler/*.sh"].sort.each do |test_script|
      if args.empty? or args.include?(File.basename(test_script, ".*"))
        sh env, test_script
      end
    end
  end
  private :test_compiler

  def test_cexts(*args)
    all_tests = %w(tools openssl minimum method module globals backtraces xopenssl gems)
    no_openssl = args.delete('--no-openssl')
    no_gems = args.delete('--no-gems')
    tests = args.empty? ? all_tests : all_tests & args
    tests -= %w[openssl xopenssl] if no_openssl
    tests.delete 'gems' if no_gems

    tests.each do |test_name|
      case test_name
      when 'tools'
        # Test tools
        sh RbConfig.ruby, 'test/truffle/cexts/test-preprocess.rb'

      when 'openssl'
        # Test that we can compile and run some basic C code that uses openssl
        if ENV['OPENSSL_PREFIX']
          openssl_cflags = ['-I', "#{ENV['OPENSSL_PREFIX']}/include"]
          openssl_lib = "#{ENV['OPENSSL_PREFIX']}/lib/libssl.#{SO}"
        else
          openssl_cflags = []
          openssl_lib = "libssl.#{SO}"
        end

        sh 'clang', '-c', '-emit-llvm', *openssl_cflags, 'test/truffle/cexts/xopenssl/main.c', '-o', 'test/truffle/cexts/xopenssl/main.bc'
        out, _ = mx('lli', "-Dpolyglot.llvm.libraries=#{openssl_lib}", 'test/truffle/cexts/xopenssl/main.bc', capture: true)
        raise out.inspect unless out == "5d41402abc4b2a76b9719d911017c592\n"

      when 'minimum', 'method', 'module', 'globals', 'backtraces', 'xopenssl'
        # Test that we can compile and run some very basic C extensions

        begin
          output_file = 'cext-output.txt'
          dir = "#{TRUFFLERUBY_DIR}/test/truffle/cexts/#{test_name}"
          cextc(dir)
          run_ruby "-I#{dir}/lib", "#{dir}/bin/#{test_name}", out: output_file
          actual = File.read(output_file)
          expected_file = "#{dir}/expected.txt"
          expected = File.read(expected_file)
          unless actual == expected
            abort <<-EOS
C extension #{dir} didn't work as expected

Actual:
#{actual}

Expected:
#{expected}

Diff:
#{Utilities.diff(expected_file, output_file)}
EOS
          end
        ensure
          File.delete output_file if File.exist? output_file
        end

      when 'gems'
        # Test that we can compile and run some real C extensions

          gem_home = "#{gem_test_pack}/gems"

          tests = [
              ['oily_png', ['chunky_png-1.3.6', 'oily_png-1.2.0'], ['oily_png']],
              ['psd_native', ['chunky_png-1.3.6', 'oily_png-1.2.0', 'bindata-2.3.1', 'hashie-3.4.4', 'psd-enginedata-1.1.1', 'psd-2.1.2', 'psd_native-1.1.3'], ['oily_png', 'psd_native']],
              ['nokogiri', [], ['nokogiri']]
          ]

          tests.each do |gem_name, dependencies, libs|
            puts "", gem_name
            next if gem_name == 'nokogiri' # nokogiri totally excluded
            gem_root = "#{TRUFFLERUBY_DIR}/test/truffle/cexts/#{gem_name}"
            ext_dir = Dir.glob("#{gem_home}/gems/#{gem_name}*/")[0] + "ext/#{gem_name}"

            compile_cext gem_name, ext_dir, "#{gem_root}/lib/#{gem_name}/#{gem_name}.su", '-Werror=implicit-function-declaration'

            next if gem_name == 'psd_native' # psd_native is excluded just for running
            run_ruby *dependencies.map { |d| "-I#{gem_home}/gems/#{d}/lib" },
                     *libs.map { |l| "-I#{TRUFFLERUBY_DIR}/test/truffle/cexts/#{l}/lib" },
                     "#{TRUFFLERUBY_DIR}/test/truffle/cexts/#{gem_name}/test.rb", gem_root
          end

          # Tests using gem install to compile the cexts
          sh "test/truffle/cexts/puma/puma.sh"
          sh "test/truffle/cexts/sqlite3/sqlite3.sh"
          sh "test/truffle/cexts/unf_ext/unf_ext.sh"

      else
        raise "unknown test: #{test_name}"
      end
    end
  end
  private :test_cexts

  def test_report(component)
    test 'specs', '--truffle-formatter', component
    sh 'ant', '-f', 'spec/buildTestReports.xml'
  end
  private :test_report

  def check_test_port
    lsof = `lsof -i :14873`
    unless lsof.empty?
      STDERR.puts 'Someone is already listening on port 14873 - our tests can\'t run'
      STDERR.puts lsof
      exit 1
    end
  end

  def test_integration(*args)
    tests_path             = "#{TRUFFLERUBY_DIR}/test/truffle/integration"
    single_test            = !args.empty?
    test_names             = single_test ? '{' + args.join(',') + '}' : '*'

    Dir["#{tests_path}/#{test_names}.sh"].sort.each do |test_script|
      check_test_port
      sh test_script
    end
  end
  private :test_integration

  def test_gems(*args)
    gem_test_pack

    tests_path             = "#{TRUFFLERUBY_DIR}/test/truffle/gems"
    single_test            = !args.empty?
    test_names             = single_test ? '{' + args.join(',') + '}' : '*'

    Dir["#{tests_path}/#{test_names}.sh"].sort.each do |test_script|
      check_test_port
      sh test_script
    end
  end
  private :test_gems

  def test_ecosystem(*args)
    gem_test_pack

    tests_path             = "#{TRUFFLERUBY_DIR}/test/truffle/ecosystem"
    single_test            = !args.empty?
    test_names             = single_test ? '{' + args.join(',') + '}' : '*'

    candidates = Dir["#{tests_path}/#{test_names}.sh"].sort
    if candidates.empty?
      targets = Dir["#{tests_path}/*.sh"].sort.map { |f| File.basename(f, ".*") }
      puts "No targets found by pattern #{test_names}. Available targets: "
      targets.each { |t| puts " * #{t}" }
      exit 1
    end
    success = candidates.all? do |test_script|
      sh test_script, continue_on_failure: true
    end
    exit success
  end
  private :test_ecosystem

  def test_bundle(*args)

    require 'tmpdir'

    gems    = [{ name:   'algebrick',
                 url:    'https://github.com/pitr-ch/algebrick.git',
                 commit: '473eb80d200fb7ad0a9b869bb0b4971fa507028a' }]
    jdebug = args.delete '--jdebug'

    gems.each do |info|
      gem_name = info.fetch(:name)
      temp_dir = Dir.mktmpdir(gem_name)

      begin
        gem_home = File.join(temp_dir, 'gem_home')

        Dir.mkdir(gem_home)
        gem_home = File.realpath gem_home # remove symlinks
        puts "Using temporary GEM_HOME:#{gem_home}"

        chdir(temp_dir) do
          puts "Cloning gem #{gem_name} into temp directory: #{temp_dir}"
          raw_sh('git', 'clone', info.fetch(:url))
        end

        gem_checkout = File.join(temp_dir, gem_name)
        chdir(gem_checkout) do
          raw_sh('git', 'checkout', info.fetch(:commit)) if info.key?(:commit)

          environment = Utilities.no_gem_vars_env.merge(
            'GEM_HOME' => gem_home,
            # add bin from gem_home to PATH
            'PATH'     => [File.join(gem_home, 'bin'), ENV['PATH']].join(File::PATH_SEPARATOR))

          run_ruby(environment, '-Xexceptions.print_java=true', *('--jdebug' if jdebug),
                   '-S', 'gem', 'install', '--no-document', 'bundler', '-v', '1.16.1', '--backtrace')
          run_ruby(environment, '-J-Xmx512M', '-Xexceptions.print_java=true', *('--jdebug' if jdebug),
                   '-S', 'bundle', 'install')
          run_ruby(environment, '-Xexceptions.print_java=true', *('--jdebug' if jdebug),
                   '-S', 'bundle', 'exec', 'rake')
        end
      ensure
        FileUtils.remove_entry temp_dir
      end
    end
  end

  def mspec(*args)
    super(*args)
  end

  def test_specs(command, *args)
    env_vars = {}
    options = []

    case command
    when 'run'
      options += %w[--excl-tag fails]
    when 'tag'
      options += %w[--add fails --fail --excl-tag fails]
    when 'untag'
      options += %w[--del fails --pass]
      command = 'tag'
    when 'tag_all'
      options += %w[--unguarded --all --dry-run --add fails]
      command = 'tag'
    else
      raise command
    end

    if args.first == 'fast'
      args.shift
      options += %w[--excl-tag slow]
    end

    if args.delete('--native')
      verify_native_bin!

      options += %w[--excl-tag graalvm --excl-tag aot]
      options << '-t' << Utilities.find_launcher(true)
      options << "-T-Xhome=#{TRUFFLERUBY_DIR}" unless args.delete('--no-home')
    end

    if args.delete('--graal')
      javacmd, javacmd_options = Utilities.find_graal_javacmd_and_options
      env_vars["JAVACMD"] = javacmd
      options.concat %w[--excl-tag graalvm]
      options.concat javacmd_options.map { |o| "-T#{o}" }
    end

    if args.delete('--jdebug')
      options << "-T#{JDEBUG}"
    end

    if args.delete('--jexception') || args.delete('--jexceptions')
      options << "-T#{JEXCEPTION}"
    end

    if args.delete('--truffle-formatter')
      options += %w[--format spec/truffle_formatter.rb]
    end

    if ENV['CI']
      options += %w[--format specdoc]
    end

    if args.any? { |arg| arg.include? 'optional/capi' } or
        args.include?(':capi') or args.include?(':library_cext')
      build("cexts")
    end

    mspec env_vars, command, *options, *args
  end
  private :test_specs

  def gem_test_pack
    name = "truffleruby-gem-test-pack"
    gem_test_pack = File.expand_path(name, TRUFFLERUBY_DIR)
    unless Dir.exist?(gem_test_pack)
      $stderr.puts "Cloning the truffleruby-gem-test-pack repository"
      url = mx('urlrewrite', "https://github.com/graalvm/#{name}.git", capture: true).first.rstrip
      sh "git", "clone", url
    end

    current = `git -C #{gem_test_pack} rev-parse HEAD`.chomp
    unless current == TRUFFLERUBY_GEM_TEST_PACK_VERSION
      Remotes.try_fetch(gem_test_pack)
      raw_sh "git", "-C", gem_test_pack, "checkout", "-q", TRUFFLERUBY_GEM_TEST_PACK_VERSION
    end

    puts gem_test_pack
    gem_test_pack
  end
  alias_method :'gem-test-pack', :gem_test_pack

  def tag(path, *args)
    return tag_all(*args) if path == 'all'
    test_specs('tag', path, *args)
  end

  # Add tags to all given examples without running them. Useful to avoid file exclusions.
  def tag_all(*args)
    test_specs('tag_all', *args)
  end
  private :tag_all

  def untag(path, *args)
    puts
    puts "WARNING: untag is currently not very reliable - run `jt test #{[path,*args] * ' '}` after and manually annotate any new failures"
    puts
    test_specs('untag', path, *args)
  end

  def build_stats(attribute, *args)
    use_json = args.delete '--json'

    value = case attribute
      when 'binary-size'
        build_stats_native_binary_size(*args)
      when 'build-time'
        build_stats_native_build_time(*args)
      when 'runtime-compilable-methods'
        build_stats_native_runtime_compilable_methods(*args)
      else
        raise ArgumentError, attribute
      end

    if use_json
      puts JSON.generate({ attribute => value })
    else
      puts "#{attribute}: #{value}"
    end
  end

  def build_stats_native_binary_size(*args)
    File.size(Utilities.find_launcher(true)) / 1024.0 / 1024.0
  end

  def build_stats_native_build_time(*args)
    log = File.read('aot-build.log')
    log =~ /\[total\]: (?<build_time>.+) ms/m
    Float($~[:build_time].gsub(',', '')) / 1000.0
  end

  def build_stats_native_runtime_compilable_methods(*args)
    log = File.read('aot-build.log')
    log =~ /(?<method_count>\d+) method\(s\) included for runtime compilation/m
    Integer($~[:method_count])
  end

  def metrics(command, *args)
    trap(:INT) { puts; exit }
    args = args.dup
    case command
    when 'alloc'
      metrics_alloc *args
    when 'minheap'
      metrics_minheap *args
    when 'maxrss'
      metrics_maxrss *args
    when 'instructions'
      metrics_native_instructions *args
    when 'time'
      metrics_time *args
    else
      raise ArgumentError, command
    end
  end

  def metrics_alloc(*args)
    use_json = args.delete '--json'
    samples = []
    METRICS_REPS.times do
      Utilities.log '.', "sampling\n"
      out, err = run_ruby '-J-Dtruffleruby.metrics.memory_used_on_exit=true', '-J-verbose:gc', *args, capture: true, no_print_cmd: true
      samples.push memory_allocated(out+err)
    end
    Utilities.log "\n", nil
    range = samples.max - samples.min
    error = range / 2
    median = samples.min + error
    human_readable = "#{Utilities.human_size(median)} ± #{Utilities.human_size(error)}"
    if use_json
      puts JSON.generate({
          samples: samples,
          median: median,
          error: error,
          human: human_readable
      })
    else
      puts human_readable
    end
  end

  def memory_allocated(trace)
    allocated = 0
    trace.lines do |line|
      case line
      when /(\d+)K->(\d+)K/
        before = $1.to_i * 1024
        after = $2.to_i * 1024
        collected = before - after
        allocated += collected
      when /^allocated (\d+)$/
        allocated += $1.to_i
      end
    end
    allocated
  end

  def metrics_minheap(*args)
    use_json = args.delete '--json'
    heap = 10
    Utilities.log '>', "Trying #{heap} MB\n"
    until can_run_in_heap(heap, *args)
      heap += 10
      Utilities.log '>', "Trying #{heap} MB\n"
    end
    heap -= 9
    heap = 1 if heap == 0
    successful = 0
    loop do
      if successful > 0
        Utilities.log '?', "Verifying #{heap} MB\n"
      else
        Utilities.log '+', "Trying #{heap} MB\n"
      end
      if can_run_in_heap(heap, *args)
        successful += 1
        break if successful == METRICS_REPS
      else
        heap += 1
        successful = 0
      end
    end
    Utilities.log "\n", nil
    human_readable = "#{heap} MB"
    if use_json
      puts JSON.generate({
          min: heap,
          human: human_readable
      })
    else
      puts human_readable
    end
  end

  def can_run_in_heap(heap, *command)
    run_ruby("-J-Xmx#{heap}M", *command, err: '/dev/null', out: '/dev/null', no_print_cmd: true, continue_on_failure: true, timeout: 60)
  end

  def metrics_maxrss(*args)
    verify_native_bin!

    use_json = args.delete '--json'
    samples = []

    METRICS_REPS.times do
      Utilities.log '.', "sampling\n"

      max_rss_in_mb = if LINUX
                        out, err = raw_sh('/usr/bin/time', '-v', '--', Utilities.find_launcher(true), *args, capture: true, no_print_cmd: true)
                        err =~ /Maximum resident set size \(kbytes\): (?<max_rss_in_kb>\d+)/m
                        Integer($~[:max_rss_in_kb]) / 1024.0
                      elsif MAC
                        out, err = raw_sh('/usr/bin/time', '-l', '--', Utilities.find_launcher(true), *args, capture: true, no_print_cmd: true)
                        err =~ /(?<max_rss_in_bytes>\d+)\s+maximum resident set size/m
                        Integer($~[:max_rss_in_bytes]) / 1024.0 / 1024.0
                      else
                        raise "Can't measure RSS on this platform."
                      end

      samples.push(maxrss: max_rss_in_mb)
    end
    Utilities.log "\n", nil

    results = {}
    samples[0].each_key do |region|
      region_samples = samples.map { |s| s[region] }
      mean = region_samples.inject(:+) / samples.size
      human = "#{region} #{mean.round(2)} MB"
      results[region] = {
          samples: region_samples,
          mean: mean,
          human: human
      }
      if use_json
        file = STDERR
      else
        file = STDOUT
      end
      file.puts region[/\s*/] + human
    end
    if use_json
      puts JSON.generate(Hash[results.map { |key, values| [key, values] }])
    end
  end

  def metrics_native_instructions(*args)
    verify_native_bin!

    use_json = args.delete '--json'

    out, err = raw_sh('perf', 'stat', '-e', 'instructions', '--', Utilities.find_launcher(true), *args, capture: true, no_print_cmd: true)

    err =~ /(?<instruction_count>[\d,]+)\s+instructions/m
    instruction_count = $~[:instruction_count].gsub(',', '')

    Utilities.log "\n", nil
    human_readable = "#{instruction_count} instructions"
    if use_json
      puts JSON.generate({
          instructions: Integer(instruction_count),
          human: human_readable
      })
    else
      puts human_readable
    end
  end

  def metrics_time(*args)
    use_json = args.delete '--json'
    samples = []
    native = args.include? '--native'
    metrics_time_option = "#{'-J' unless native}-Dtruffleruby.metrics.time=true"
    METRICS_REPS.times do
      Utilities.log '.', "sampling\n"
      start = Time.now
      out, err = run_ruby metrics_time_option, '--no-core-load-path', *args, capture: true, no_print_cmd: true
      $stdout.puts out unless out.empty?
      finish = Time.now
      samples.push get_times(err, finish - start)
    end
    Utilities.log "\n", nil
    results = {}
    samples[0].each_key do |region|
      region_samples = samples.map { |s| s[region] }
      mean = region_samples.inject(:+) / samples.size
      human = "#{'%.3f' % mean} #{region.strip}"
      results[region.strip] = {
          samples: region_samples,
          mean: mean,
          human: human
      }
      if use_json
        STDERR.puts region[/\s*/] + human
      else
        STDOUT.puts region[/\s*/] + human
      end
    end
    if use_json
      puts JSON.generate(results)
    end
  end

  def get_times(trace, total)
    indent = ' '
    times = {
      'total' => 0,
      "#{indent}jvm" => 0,
    }
    depth = 0
    run_depth = -1
    accounted_for = 0
    trace.lines do |line|
      if line =~ /^(.+) (\d+\.\d+)$/
        region = $1
        time = $2.to_f
        if region.start_with? 'before-'
          depth += 1
          key = (indent * depth + region['before-'.size..-1])
          if prev = times[key]
            # Already a time with the same key, add them together
            times[key] = time - prev
          else
            times[key] = time
          end
          run_depth = depth if region == 'before-run'
        elsif region.start_with? 'after-'
          key = (indent * depth + region['after-'.size..-1])
          start = times[key]
          raise "#{region} without matching before: #{key.inspect} #{times.inspect}" unless start
          elapsed = time - start
          if depth == run_depth+1
            accounted_for += elapsed
          elsif region == 'after-run'
            times[indent * (depth+1) + 'unaccounted'] = elapsed - accounted_for
          end
          depth -= 1
          times[key] = elapsed
        end
      else
        $stderr.puts line
      end
    end
    if main = times["#{indent}main"]
      times["#{indent}jvm"] = total - main
    end
    times['total'] = total
    times
  end

  def benchmark(*args)
    args.map! do |a|
      if a.include?('.rb')
        benchmark = Utilities.find_benchmark(a)
        raise 'benchmark not found' unless File.exist?(benchmark)
        benchmark
      else
        a
      end
    end

    benchmark_ruby = ENV['JT_BENCHMARK_RUBY']

    run_args = []

    if args.delete('--native') || (ENV.has_key?('JT_BENCHMARK_RUBY') && (ENV['JT_BENCHMARK_RUBY'] == Utilities.find_launcher(true)))
      run_args.push "-Xhome=#{TRUFFLERUBY_DIR}"

      # We already have a mechanism for setting the Ruby to benchmark, but elsewhere we use AOT_BIN with the "--native" flag.
      # Favor JT_BENCHMARK_RUBY to AOT_BIN, but try both.
      benchmark_ruby ||= Utilities.find_launcher(true)

      unless File.exist?(benchmark_ruby.to_s)
        raise "Could not find benchmark ruby -- '#{benchmark_ruby}' does not exist"
      end
    end

    unless benchmark_ruby
      run_args.push '--graal' unless args.delete('--no-graal') || args.include?('list')
      run_args.push '-J-Dgraal.TruffleCompilationExceptionsAreFatal=true'
    end

    run_args.push "-I#{Utilities.find_gem('benchmark-ips')}/lib" rescue nil
    run_args.push "#{TRUFFLERUBY_DIR}/bench/benchmark-interface/bin/benchmark"
    run_args.push *args

    if benchmark_ruby
      sh benchmark_ruby, *run_args
    else
      run_ruby *run_args
    end
  end

  def where(*args)
    case args.shift
    when 'repos'
      args.each do |a|
        puts Utilities.find_repo(a)
      end
    end
  end

  def install(name, *options)
    case name
    when "jvmci"
      install_jvmci
    when "graal", "graal-core"
      install_graal *options
    else
      raise "Unknown how to install #{what}"
    end
  end

  def install_jvmci
    raise "Installing JVMCI is only available on Linux and macOS currently" unless LINUX || MAC

    update, jvmci_version = Utilities.jvmci_version
    dir = File.expand_path("..", TRUFFLERUBY_DIR)
    java_home = chdir(dir) do
      if LINUX
        dir_pattern = "#{dir}/openjdk1.8.0*#{jvmci_version}"
        if Dir[dir_pattern].empty?
          puts "Downloading JDK8 with JVMCI"
          jvmci_releases = "https://github.com/graalvm/openjdk8-jvmci-builder/releases/download"
          filename = "openjdk-8u#{update}-#{jvmci_version}-linux-amd64.tar.gz"
          raw_sh "curl", "-L", "#{jvmci_releases}/#{jvmci_version}/#{filename}", "-o", filename
          raw_sh "tar", "xf", filename
        end
        dirs = Dir[dir_pattern]
        raise 'ambiguous JVMCI directories' if dirs.length != 1
        dirs.first
      elsif MAC
        dir_pattern = "#{dir}/labsjdk1.8.0*-#{jvmci_version}"
        if Dir[dir_pattern].empty?
          archive_pattern = "#{dir}/labsjdk-8*-#{jvmci_version}-darwin-amd64.tar.gz"
          archives = Dir[archive_pattern]
          if archives.empty?
            puts "You need to download manually the latest JVMCI-enabled JDK at"
            puts "http://www.oracle.com/technetwork/oracle-labs/program-languages/downloads/index.html"
            puts "Download the file named labsjdk-8...-#{jvmci_version}-darwin-amd64.tar.gz"
            puts "And move it to the directory #{dir}"
            exit 1
          end
          raise 'ambiguous JVMCI archives' if archives.length != 1
          raw_sh "tar", "xf", archives.first
        end
        dirs = Dir[dir_pattern]
        raise 'ambiguous JVMCI directories' if dirs.length != 1
        "#{dirs.first}/Contents/Home"
      end
    end

    abort "Could not find the extracted JDK" unless java_home
    java_home = File.expand_path(java_home)

    $stderr.puts "Testing JDK"
    raw_sh "#{java_home}/bin/java", "-version"

    puts java_home
    java_home
  end

  def checkout_or_update_graal_repo(sforceimports: true)
    graal = Utilities.find_or_clone_repo('https://github.com/graalvm/graal.git')

    if sforceimports
      Remotes.try_fetch(graal)
      raw_sh "git", "-C", graal, "checkout", Utilities.truffle_version
    end

    graal
  end

  def install_graal(*options)
    build
    java_home = install_jvmci unless options.include?("--no-jvmci")
    graal = checkout_or_update_graal_repo

    puts "Building graal"
    chdir("#{graal}/compiler") do
      mx "build", java_home: java_home
    end

    puts "Running with Graal"
    run_ruby "--graal", "-e", "p TruffleRuby.graal?"

    puts
    puts "To run TruffleRuby with Graal, use:"
    puts "$ #{TRUFFLERUBY_DIR}/tool/jt.rb ruby --graal ..."
  end

  def build_native_image(*options)
    sulong = !options.delete("--no-sulong")
    jvmci = !options.delete("--no-jvmci")
    sforceimports = !options.delete("--no-sforceimports")
    tools = !options.delete("--no-tools")

    build_truffleruby(sforceimports: sforceimports)

    java_home = install_jvmci if jvmci
    graal = checkout_or_update_graal_repo(sforceimports: sforceimports)

    puts 'Building TruffleRuby native binary'
    chdir("#{graal}/substratevm") do
      mx 'build', java_home: java_home
      mx '--dynamicimports', '/tools',
         'fetch-languages',
         '--language:llvm', '--language:ruby',
         '--tool:chromeinspector', '--tool:profiler',
         java_home: java_home

      languages = %w[--language:ruby]
      languages.unshift '--language:llvm' if sulong
      if tools
        languages.push '--tool:chromeinspector', '--tool:profiler'
      end

      output_options = [
          "-H:Path=#{TRUFFLERUBY_DIR}/bin",
          '-H:Name=native-ruby',
          '-H:Class=org.truffleruby.launcher.RubyLauncher']

      mx 'native-image', *languages, *output_options, *options, java_home: java_home
    end
  end

  def next(*args)
    puts `cat spec/tags/core/**/**.txt | grep 'fails:'`.lines.sample
  end

  def native_launcher
    sh "cc", "-o", "tool/native_launcher_darwin", "tool/native_launcher_darwin.c"
  end
  alias :'native-launcher' :native_launcher

  def check_dsl_usage
    mx 'clean'
    # We need to build with -parameters to get parameter names
    build_truffleruby('-A-parameters')
    run_ruby({ "TRUFFLE_CHECK_DSL_USAGE" => "true" }, '-Xlazy.default=false', '-e', 'exit')
  end

  def rubocop(*args)
    gem_home = "#{gem_test_pack}/rubocop-gems"
    env = {
      "GEM_HOME" => gem_home,
      "GEM_PATH" => gem_home,
      "PATH" => "#{gem_home}/bin:#{ENV['PATH']}"
    }
    sh env, "ruby", "#{gem_home}/bin/rubocop", *RUBOCOP_INCLUDE_LIST, *args
  end

  def check_filename_length
    # For eCryptfs, see https://bugs.launchpad.net/ecryptfs/+bug/344878
    max_length = 143

    too_long = []
    Dir.chdir(TRUFFLERUBY_DIR) do
      Dir.glob("**/*") do |f|
        if File.basename(f).size > max_length
          too_long << f
        end
      end
    end

    unless too_long.empty?
      abort "Too long filenames for eCryptfs:\n#{too_long.join "\n"}"
    end
  end

  def check_parser
    build('parser')
    diff, _err = sh 'git', 'diff', 'src/main/java/org/truffleruby/parser/parser/RubyParser.java', :err => :out, capture: true
    unless diff.empty?
      STDERR.puts "DIFF:"
      STDERR.puts diff
      abort "RubyParser.y must be modified and RubyParser.java regenerated by 'jt build parser'"
    end
  end

  def check_documentation_urls
    url_base = 'https://github.com/oracle/truffleruby/blob/master/doc/'
    # Explicit list of URLs, so they can be added manually
    # Notably, Ruby installers reference the LLVM urls
    known_hardcoded_urls = %w[
      https://github.com/oracle/truffleruby/blob/master/doc/user/installing-libssl.md
      https://github.com/oracle/truffleruby/blob/master/doc/user/installing-llvm.md
      https://github.com/oracle/truffleruby/blob/master/doc/user/installing-zlib.md
    ]

    known_hardcoded_urls.each { |url|
      file = url[url_base.size..-1]
      path = "#{TRUFFLERUBY_DIR}/doc/#{file}"
      unless File.file?(path)
        abort "#{path} could not be found but is referenced in code"
      end
    }

    hardcoded_urls = `git -C #{TRUFFLERUBY_DIR} grep -Fn #{url_base.inspect}`
    hardcoded_urls.each_line { |line|
      abort "Could not parse #{line.inspect}" unless /(.+?):(\d+):.+?(https:.+?)[ "'\n]/ =~ line
      file, line, url = $1, $2, $3
      if file != 'tool/jt.rb' and !known_hardcoded_urls.include?(url)
        abort "Found unknown hardcoded url #{url} in #{file}:#{line}, add it in tool/jt.rb"
      end
    }
  end

  def lint(*args)
    check_dsl_usage unless args.delete '--no-build'
    check_filename_length
    rubocop
    sh "tool/lint.sh"
    mx 'checkstyle'
    check_parser
    check_documentation_urls
  end

  def verify_native_bin!
    unless File.exist?(Utilities.find_launcher(true))
      raise "Could not find native image -- either build with 'jt build native' or set AOT_BIN to an image location"
    end
  end

  def docker(*args)
    command = args.shift
    case command
    when 'build'
      docker_build *args
    when nil, 'test'
      docker_test *args
    when 'print'
      docker_print *args
    when 'extract-standalone'
      docker_extract_standalone *args
    else
      abort "Unkown jt docker command #{command}"
    end
  end

  def docker_build(*args)
    if args.first.nil? || args.first.start_with?('--')
      image_name = 'truffleruby-test'
    else
      image_name = args.shift
    end
    docker_dir = File.join(TRUFFLERUBY_DIR, 'tool', 'docker')
    File.write(File.join(docker_dir, 'Dockerfile'), dockerfile(*args))
    sh 'docker', 'build', '-t', image_name, '.', chdir: docker_dir
  end

  def docker_test(*args)
    distros = ['--ol7', '--ubuntu1604', '--fedora25']
    managers = ['--no-manager', '--rbenv', '--chruby', '--rvm']

    distros.each do |distro|
      managers.each do |manager|
        docker 'build', distro, manager, *args
      end
    end
  end

  def docker_print(*args)
    puts dockerfile(*args)
  end

  def dockerfile(*args)
    config = @config ||= YAML.load_file(File.join(TRUFFLERUBY_DIR, 'tool', 'docker-configs.yaml'))

    truffleruby_repo = 'https://github.com/oracle/truffleruby.git'
    distro = 'ubuntu1604'
    install_method = :public
    public_version = '1.0.0-rc2'
    rebuild_images = false
    rebuild_openssl = true
    manager = :none
    basic_test = false
    full_test = false

    until args.empty?
      arg = args.shift
      case arg
      when '--repo'
        truffleruby_repo = args.shift
      when '--ol7', '--ubuntu1604', '--fedora25'
        distro = arg[2..-1]
      when '--public'
        install_method = :public
        public_version = args.shift
      when '--graalvm'
        install_method = :graalvm
        graalvm_tarball = args.shift
        graalvm_component = args.shift
      when '--standalone'
        install_method = :standalone
        standalone_tarball = args.shift
      when '--source'
        install_method = :source
        source_branch = args.shift
      when '--rebuild-images'
        rebuild_images = true
      when '--no-rebuild-openssl'
        rebuild_openssl = false
      when '--no-manager'
        manager = :none
      when '--rbenv', '--chruby', '--rvm'
        manager = arg[2..-1].to_sym
      when '--basic-test'
        basic_test = true
      when '--test'
        full_test = true
        test_branch = args.shift
      else
        abort "unknown option #{arg}"
      end
    end

    distro = config.fetch(distro)
    run_post_install_hook = rebuild_openssl && distro.fetch('post-install')

    lines = []

    lines.push "FROM #{distro.fetch('base')}"

    lines.push *distro.fetch('setup')

    lines.push *distro.fetch('locale')

    lines.push *distro.fetch('curl') if install_method == :public
    lines.push *distro.fetch('git') if install_method == :source || manager != :none || full_test
    lines.push *distro.fetch('which') if manager == :rvm || full_test
    lines.push *distro.fetch('find') if full_test
    lines.push *distro.fetch('rvm') if manager == :rvm
    lines.push *distro.fetch('source') if install_method == :source
    lines.push *distro.fetch('images') if rebuild_images

    lines.push *distro.fetch('openssl')
    lines.push *distro.fetch('cext')
    lines.push *distro.fetch('cppext')

    lines.push "WORKDIR /test"
    lines.push "RUN useradd -ms /bin/bash test"
    lines.push "RUN chown test /test"
    lines.push "USER test"

    docker_dir = File.join(TRUFFLERUBY_DIR, 'tool', 'docker')

    case install_method
    when :graalvm
      tarball = graalvm_tarball
    when :standalone
      tarball = standalone_tarball
    end

    if defined?(tarball)
      graalvm_version = /([ce]e-)?\d+(\.\d+)*(-rc\d+)?(\-dev)?(-\h+)?/.match(tarball).to_s

      # Test build tarballs may have a -bn suffix, which isn't really part of the version string but matches the hex part in some cases
      graalvm_version = graalvm_version.gsub(/-b\d+\Z/, '')
    end
    
    check_post_install_message = [
      "RUN grep 'The Ruby openssl C extension needs to be recompiled on your system to work with the installed libssl' install.log",
      "RUN grep '/jre/languages/ruby/lib/truffle/post_install_hook.sh' install.log"
    ]

    case install_method
    when :public
      lines.push "RUN curl -OL https://github.com/oracle/graal/releases/download/vm-#{public_version}/graalvm-ce-#{public_version}-linux-amd64.tar.gz"
      lines.push "RUN tar -zxf graalvm-ce-#{public_version}-linux-amd64.tar.gz"
      lines.push "ENV D_GRAALVM_BASE=/test/graalvm-ce-#{public_version}"
      lines.push "RUN $D_GRAALVM_BASE/bin/gu install org.graalvm.ruby | tee install.log"
      lines.push(*check_post_install_message)
      lines.push "ENV D_RUBY_BASE=$D_GRAALVM_BASE/jre/languages/ruby"
      lines.push "ENV D_RUBY_BIN=$D_GRAALVM_BASE/bin"
      lines.push "RUN PATH=$D_RUBY_BIN:$PATH $D_RUBY_BASE/lib/truffle/post_install_hook.sh" if run_post_install_hook
    when :graalvm
      FileUtils.copy graalvm_tarball, docker_dir
      FileUtils.copy graalvm_component, docker_dir
      graalvm_tarball = File.basename(graalvm_tarball)
      graalvm_component = File.basename(graalvm_component)
      lines.push "COPY #{graalvm_tarball} /test/"
      lines.push "COPY #{graalvm_component} /test/"
      lines.push "RUN tar -zxf #{graalvm_tarball}"
      lines.push "ENV D_GRAALVM_BASE=/test/graalvm-#{graalvm_version}"
      lines.push "RUN $D_GRAALVM_BASE/bin/gu install --file /test/#{graalvm_component} | tee install.log"
      lines.push(*check_post_install_message)
      lines.push "ENV D_RUBY_BASE=$D_GRAALVM_BASE/jre/languages/ruby"
      lines.push "ENV D_RUBY_BIN=$D_GRAALVM_BASE/bin"
      lines.push "RUN PATH=$D_RUBY_BIN:$PATH $D_RUBY_BASE/lib/truffle/post_install_hook.sh" if run_post_install_hook
    when :standalone
      FileUtils.copy standalone_tarball, docker_dir
      standalone_tarball = File.basename(standalone_tarball)
      lines.push "COPY #{standalone_tarball} /test/"
      lines.push "RUN tar -zxf #{standalone_tarball}"
      lines.push "ENV D_RUBY_BASE=/test/#{File.basename(standalone_tarball, '.tar.gz')}"
      lines.push "ENV D_RUBY_BIN=$D_RUBY_BASE/bin"
      lines.push "RUN PATH=$D_RUBY_BIN:$PATH $D_RUBY_BASE/lib/truffle/post_install_hook.sh" if run_post_install_hook
    when :source
      lines.push "RUN git clone --depth 1 https://github.com/graalvm/mx.git"
      lines.push "ENV PATH=$PATH:/test/mx"
      lines.push "RUN git clone --depth 1 https://github.com/graalvm/graal-jvmci-8.git"
      lines.push "RUN cd graal-jvmci-8 && mx build"
      lines.push "ENV JAVA_HOME=/test/graal-jvmci-8/#{distro.fetch('jdk')}/linux-amd64/product"
      lines.push "ENV JAVA_BIN=$JAVA_HOME/bin/java"
      lines.push "ENV JVMCI_VERSION_CHECK=ignore"
      lines.push "RUN $JAVA_HOME/bin/java -version"
      lines.push "RUN git clone --depth 1 --branch #{source_branch} #{truffleruby_repo}"
      lines.push "RUN cd truffleruby && mx build"
      lines.push "RUN cd graal/compiler && mx build"
      lines.push "ENV JAVACMD=$JAVA_BIN"
      lines.push "ENV JAVA_OPTS='-XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -Djvmci.class.path.append=/test/graal/compiler/mxbuild/dists/graal.jar'"
      lines.push "ENV D_RUBY_BASE=/test/truffleruby"
      lines.push "ENV D_RUBY_BIN=$D_RUBY_BASE/bin"
    end

    if rebuild_images
      if [:public, :graalvm].include?(install_method)
        lines.push "RUN $D_GRAALVM_BASE/bin/gu rebuild-images ruby"
      else
        abort "can't rebuild images for a build not from public or from local GraalVM components"
      end
    end

    case manager
    when :none
      lines.push "ENV PATH=$D_RUBY_BASE/bin:$PATH"

      setup_env = lambda do |command|
        command
      end
    when :rbenv
      lines.push "RUN git clone --depth 1 https://github.com/rbenv/rbenv.git /home/test/.rbenv"
      lines.push "RUN mkdir /home/test/.rbenv/versions"
      lines.push "ENV PATH=/home/test/.rbenv/bin:$PATH"
      lines.push "RUN rbenv --version"

      lines.push "RUN ln -s $D_RUBY_BASE /home/test/.rbenv/versions/truffleruby"
      lines.push "RUN rbenv versions"

      prefix = 'eval "$(rbenv init -)" && rbenv shell truffleruby'

      setup_env = lambda do |command|
        "eval \"$(rbenv init -)\" && rbenv shell truffleruby && #{command}"
      end
    when :chruby
      lines.push "RUN git clone --depth 1 https://github.com/postmodern/chruby.git"
      lines.push "ENV CRUBY_SH=/test/chruby/share/chruby/chruby.sh"
      lines.push "RUN bash -c 'source $CRUBY_SH && chruby --version'"

      lines.push "RUN mkdir /home/test/.rubies"
      lines.push "RUN ln -s $D_RUBY_BASE /home/test/.rubies/truffleruby"
      lines.push "RUN bash -c 'source $CRUBY_SH && chruby'"

      setup_env = lambda do |command|
        "bash -c 'source $CRUBY_SH && chruby truffleruby && #{command.gsub("'", "'\\\\''")}'"
      end
    when :rvm
      lines.push "RUN git clone --depth 1 https://github.com/rvm/rvm.git"
      lines.push "ENV RVM_SCRIPT=/test/rvm/scripts/rvm"
      lines.push "RUN bash -c 'source $RVM_SCRIPT && rvm --version'"

      lines.push "RUN bash -c 'source $RVM_SCRIPT && rvm mount $D_RUBY_BASE -n truffleruby'"
      lines.push "RUN bash -c 'source $RVM_SCRIPT && rvm list'"

      setup_env = lambda do |command|
        "bash -c 'source $RVM_SCRIPT && rvm use ext-truffleruby && #{command.gsub("'", "'\\\\''")}'"
      end
    end

    configs = ['']
    configs += ['--jvm'] if [:public, :graalvm].include?(install_method)
    configs += ['--native'] if [:public, :graalvm, :standalone].include?(install_method)

    configs.each do |config|
      lines.push "RUN " + setup_env["ruby #{config} --version"]
    end

    if basic_test || full_test
      configs.each do |config|
        lines.push "RUN cp -r $D_RUBY_BASE/lib/ruby/gems /test/clean-gems"

        if config == '' && install_method != :source
          gem = "gem"
        else
          gem = "ruby #{config} -Sgem"
        end

        lines.push "RUN " + setup_env["#{gem} install color"]
        lines.push "RUN " + setup_env["ruby #{config} -rcolor -e 'raise unless defined?(Color)'"]

        lines.push "RUN " + setup_env["#{gem} install oily_png"]
        lines.push "RUN " + setup_env["ruby #{config} -roily_png -e 'raise unless defined?(OilyPNG::Color)'"]

        lines.push "RUN " + setup_env["#{gem} install unf"]
        lines.push "RUN " + setup_env["ruby #{config} -runf -e 'raise unless defined?(UNF)'"]

        lines.push "RUN rm -rf $D_RUBY_BASE/lib/ruby/gems"
        lines.push "RUN mv /test/clean-gems $D_RUBY_BASE/lib/ruby/gems"
      end
    end

    if full_test
      lines.push "RUN git clone --depth 1 --branch #{test_branch} #{truffleruby_repo} truffleruby-tests"
      lines.push "RUN cp -r truffleruby-tests/spec ."
      lines.push "RUN cp -r truffleruby-tests/test/truffle/compiler/pe ."
      lines.push "RUN rm -rf truffleruby-tests"

      configs.each do |config|
        excludes = ['fails', 'slow', 'ci']
        excludes += ['graalvm'] if [:public, :graalvm].include?(install_method)
        excludes += ['aot'] if ['', '--native'].include?(config)

        [':command_line', ':security', ':language', ':core', ':library', ':capi', ':library_cext', ':truffle'].each do |set|
          t_config = config.empty? ? '' : '-T' + config
          t_excludes = excludes.map { |e| '--excl-tag ' + e }.join(' ')
          lines.push "RUN " + setup_env["ruby spec/mspec/bin/mspec --config spec/truffle.mspec -t $D_RUBY_BIN/ruby #{t_config} #{t_excludes} #{set}"]
        end
      end

      configs.each do |config|
        if config == '--jvm'
          d = '-J-'
        else
          d = '--native.'
        end

        lines.push "RUN " + setup_env["ruby #{config} #{d}Dgraal.TruffleCompilationExceptionsAreThrown=true #{d}Dgraal.TruffleIterativePartialEscape=true -Xbasic_ops.inline=false pe/pe.rb"]
      end
    end

    lines.push "CMD " + setup_env["bash"]

    lines.join("\n") + "\n"
  end

  def docker_extract_standalone(*args)
    graalvm_component = args.shift
    version = args.shift
    if graalvm_component.include?('linux-amd64')
      platform = 'linux-amd64'
    elsif graalvm_component.include?('macos-amd64')
      platform = 'macos-amd64'
    else
      abort "cannot find platform in #{graalvm_component}"
    end
    target = "truffleruby-#{version}-#{platform}.tar.gz"
    docker_dir = File.join(TRUFFLERUBY_DIR, 'tool', 'docker')
    lines = []
    lines.push "FROM ubuntu:16.04"
    lines.push "RUN apt-get update"
    lines.push "RUN apt-get install -y ruby unzip"
    lines.push "WORKDIR /test"
    lines.push "RUN useradd -ms /bin/bash test"
    lines.push "RUN chown test /test"
    lines.push "USER test"
    lines.push "RUN mkdir tool"
    docker_dir = File.join(TRUFFLERUBY_DIR, 'tool', 'docker')
    FileUtils.copy graalvm_component, docker_dir
    graalvm_component = File.basename(graalvm_component)
    lines.push "COPY #{graalvm_component} /test/"
    ['extract-standalone-distribution.sh', 'restore-perms-symlinks.rb'].each do |file|
      FileUtils.copy File.join(TRUFFLERUBY_DIR, 'tool', file), docker_dir
      lines.push "ADD #{file} /test/tool"
    end
    lines.push "RUN tool/extract-standalone-distribution.sh /test/#{graalvm_component} #{version}"
    File.write(File.join(docker_dir, 'Dockerfile'), lines.join("\n") + "\n")
    sh 'docker', 'build', '-t', 'extract_standalone', '.', chdir: docker_dir
    sh 'docker', 'run', 'extract_standalone'
    out, _err = sh 'docker', 'run', 'extract_standalone', 'cat', "/test/#{target}", capture: true
    File.write(File.join(TRUFFLERUBY_DIR, target), out)
  end

  private :docker_build, :docker_test, :docker_print, :dockerfile, :docker_extract_standalone

end

class JT
  include Commands

  def main(args)
    args = args.dup

    if args.empty? or %w[-h -help --help].include? args.first
      help
      exit
    end

    if args.first =~ /^--((?:re)?build)$/
      send $1
      args.shift
    end

    commands = Commands.public_instance_methods(false).map(&:to_s)

    command, *rest = args
    command = "command_#{command}" if %w[p puts].include? command

    abort "no command matched #{command.inspect}" unless commands.include?(command)

    begin
      send(command, *rest)
    rescue
      puts "Error during command: #{args*' '}"
      raise $!
    end
  end
end

if $0 == __FILE__
  JT.new.main(ARGV)
end
