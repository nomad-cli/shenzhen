require 'fileutils'

command :build do |c|
  c.syntax = 'ipa build [options]'
  c.summary = 'Create a new .ipa file for your app'
  c.description = ''

  c.option '-w', '--workspace WORKSPACE', 'Workspace (.xcworkspace) file to use to build app (automatically detected in current directory)'
  c.option '-p', '--project PROJECT', 'Project (.xcodeproj) file to use to build app (automatically detected in current directory, overridden by --workspace option, if passed)'
  c.option '-c', '--configuration CONFIGURATION', 'Configuration used to build'
  c.option '-s', '--scheme SCHEME', 'Scheme used to build app'
  c.option '--[no-]clean', 'Clean project before building'
  c.option '--[no-]archive', 'Archive project after building'
  c.option '-d', '--destination DESTINATION', 'Destination. Defaults to current directory'

  c.action do |args, options|
    validate_xcode_version!

    @workspace = options.workspace
    @project = options.project unless @workspace

    @xcodebuild_info = Shenzhen::XcodeBuild.info(:workspace => @workspace, :project => @project)

    @scheme = options.scheme
    @configuration = options.configuration
    @destination = options.destination || Dir.pwd
    FileUtils.mkdir_p(@destination) unless File.directory?(@destination)

    determine_workspace_or_project! unless @workspace || @project

    determine_configuration! unless @configuration
    say_error "Configuration #{@configuration} not found" and abort unless (@xcodebuild_info.build_configurations.include?(@configuration) rescue false)

    determine_scheme! unless @scheme
    say_error "Scheme #{@scheme} not found" and abort unless (@xcodebuild_info.schemes.include?(@scheme) rescue false)

    say_warning "Building \"#{@workspace || @project}\" with Scheme \"#{@scheme}\" and Configuration \"#{@configuration}\"\n" unless options.quiet

    log "xcodebuild", (@workspace || @project)

    flags = []
    flags << "-sdk iphoneos"
    flags << "-workspace '#{@workspace}'" if @workspace
    flags << "-project '#{@project}'" if @project
    flags << "-scheme '#{@scheme}'" if @scheme
    flags << "-configuration '#{@configuration}'"

    actions = []
    actions << :clean unless options.clean == false
    actions << :build
    actions << :archive unless options.archive == false

    ENV['CC'] = nil # Fix for RVM
    abort unless system %{xcodebuild #{flags.join(' ')} #{actions.join(' ')} 1> /dev/null}

    @target, @xcodebuild_settings = Shenzhen::XcodeBuild.settings(*flags).detect{|target, settings| settings['WRAPPER_EXTENSION'] == "app"}
    say_error "App settings could not be found." and abort unless @xcodebuild_settings

    @app_path = File.join(@xcodebuild_settings['BUILT_PRODUCTS_DIR'], @xcodebuild_settings['WRAPPER_NAME'])
    @dsym_path = @app_path + ".dSYM"
    @dsym_filename = File.expand_path("#{@xcodebuild_settings['WRAPPER_NAME']}.dSYM", @destination)
    @ipa_name = @xcodebuild_settings['WRAPPER_NAME'].gsub(@xcodebuild_settings['WRAPPER_SUFFIX'], "") + ".ipa"
    @ipa_path = File.expand_path(@ipa_name, @destination)

    log "xcrun", "PackageApplication"
    abort unless system %{xcrun -sdk iphoneos PackageApplication -v "#{@app_path}" -o "#{@ipa_path}" --embed "#{@dsym_path}" 1> /dev/null}

    log "zip", @dsym_filename
    abort unless system %{cp -r "#{@dsym_path}" "#{@destination}" && zip -r "#{@dsym_filename}.zip" "#{@dsym_filename}" >/dev/null && rm -rf "#{@dsym_filename}"}

    say_ok "#{@ipa_path} successfully built" unless options.quiet
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
    configurations = @xcodebuild_info.build_configurations rescue []
    if configurations.nil? or configurations.empty? or configurations.include?("Debug")
      @configuration = "Debug"
    elsif configurations.length == 1
      @configuration = configurations.first
    end

    if @configuration
      say_warning "Configuration was not passed, defaulting to #{@configuration}"
    else
      @configuration = choose "Select a configuration:", *configurations
    end
  end
end
