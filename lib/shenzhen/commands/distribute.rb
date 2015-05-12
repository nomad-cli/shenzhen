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

def determine_dsyms!
  dsym_files = Dir['*.dSYM.zip']
  @dsyms ||= (dsym_files.length == 0 ? nil : dsym_files)
end

def determine_notes!
  placeholder = %{What's new in this release: }

  @notes = ask_editor placeholder
  @notes = nil if @notes == placeholder
end
