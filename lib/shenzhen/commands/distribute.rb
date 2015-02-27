private

def determine_file!
  files = Dir['*.ipa']
  @file ||= case files.length
            when 0 then nil
            when 1 then files.first
            else
              @file = choose "Select an .ipa File:", *files
            end
end

def determine_dsym!
  dsym_files = Dir['*.dSYM.zip']
  @dsym ||= case dsym_files.length
            when 0 then nil
            when 1 then dsym_files.first
            else
              dsym_files.detect do |dsym|
                File.basename(dsym, ".app.dSYM.zip") == File.basename(@file, ".ipa")
              end or choose "Select a .dSYM.zip file:", *dsym_files
            end
end

def determine_notes!
  placeholder = %{What's new in this release: }

  @notes = ask_editor placeholder
  @notes = nil if @notes == placeholder
end
