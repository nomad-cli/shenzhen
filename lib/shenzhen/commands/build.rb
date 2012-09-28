command :build do |c|
  c.syntax = 'ipa build [options] [output]'
  c.summary = 'Create a new .ipa file for your app'
  c.description = ''

  c.example 'description', 'ipa release 478 --tag 3.7.2 --scheme MyApp'
  c.option '-w', '--workspace WORKSPACE', 'Workspace (.xcworkspace) file to use to build app (automatically detected in current directory)'
  c.option '-p', '--project PROJECT', 'Project (.xcodeproj) file to use to build app (automatically detected in current directory, overridden by --workspace option, if passed)'
  c.option '-c', '--configuration CONFIGURATION', 'Configuration used to build'
  c.option '-s', '--scheme SCHEME', 'Scheme used to build app'
  c.option '-q', '--quiet', 'Silence warning and success messages'

  c.action do |args, options|
    validate_xcode_version!

    @xcodebuild_info = Shenzhen::XcodeBuild.info

    @workspace = options.workspace
    @project = options.project
    @scheme = options.scheme
    @configuration = options.configuration

    determine_workspace_or_project! unless @workspace || @project

    determine_configuration! unless @configuration
    say_error "Configuration #{@configuration} not found" and abort unless @xcodebuild_info.build_configurations.include?(@configuration)

    determine_scheme! unless @scheme
    say_error "Scheme #{@scheme} not found" and abort unless @xcodebuild_info.schemes.include?(@scheme)

    say_warning "Building \"#{@workspace || @project}\" with Scheme \"#{@scheme}\" and Configuration \"#{@configuration}\"\n" unless options.quiet

    log "xcodebuild", (@workspace || @project)

    flags = []
    flags << "-sdk iphoneos"
    flags << "-workspace '#{@workspace}'" if @workspace
    flags << "-project '#{@project}'" if @project
    flags << "-scheme '#{@scheme}'" if @scheme
    flags << "-configuration Release"

    ENV['CC'] = nil # Fix for RVM
    abort unless system "xcodebuild #{flags.join(' ')} clean build 1> /dev/null"

    log "xcrun", "PackageApplication"
    
    @xcodebuild_settings = Shenzhen::XcodeBuild.settings(flags)

    @app_path = File.join(@xcodebuild_settings['BUILT_PRODUCTS_DIR'], @xcodebuild_settings['PRODUCT_NAME']) + ".app"
    @dsym_path = @app_path + ".dSYM"
    @ipa_path = File.join(Dir.pwd, @xcodebuild_settings['PRODUCT_NAME']) + ".ipa"
    abort unless system %{xcrun -sdk iphoneos PackageApplication -v "#{@app_path}" -o "#{@ipa_path}" --embed "#{@dsym_path}" 1> /dev/null}

    say_ok "#{File.basename(@ipa_path)} successfully built" unless options.quiet
  end

  private

  def validate_xcode_version!
    version = Shenzhen::XcodeBuild.version
    say_error "Shenzhen requires Xcode 4 (found #{version}). Please install or switch to the latest Xcode." and abort if version < "4.0.0"
  end

  def determine_workspace_or_project!
    workspaces, projects = Dir["*.xcworkspace"], Dir["*.xcodeproj"]

    if workspaces.empty?
      if projects.empty?
        say_error "No Xcode projects or workspaces found in current directory" and abort
      else
        if projects.length == 1
          @project = projects.first
        else
          @project = choose "Select a project:", *projects
        end
      end
    else
      if workspaces.length == 1
        @workspace = workspaces.first
      else
        @workspace = choose "Select a workspace:", *workspaces
      end
    end
  end

  def determine_scheme!
    if @xcodebuild_info.schemes.length == 1
      @scheme = @xcodebuild_info.schemes.first
    else
      @scheme = choose "Select a scheme:", *@xcodebuild_info.schemes
    end
  end

  def determine_configuration!
    if @xcodebuild_info.build_configurations.length == 1
      @configuration = @xcodebuild_info.build_configurations.first
    else
      @configuration = choose "Select a configuration:", *@xcodebuild_info.build_configurations
    end
  end
end
