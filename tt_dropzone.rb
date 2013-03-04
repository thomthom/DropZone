#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
begin
  require 'TT_Lib2/core.rb'
rescue LoadError => e
  module TT
    if @lib2_update.nil?
      url = 'http://www.thomthom.net/software/sketchup/tt_lib2/errors/not-installed'
      options = {
        :dialog_title => 'TT_Lib² Not Installed',
        :scrollable => false, :resizable => false, :left => 200, :top => 200
      }
      w = UI::WebDialog.new( options )
      w.set_size( 500, 300 )
      w.set_url( "#{url}?plugin=#{File.basename( __FILE__ )}" )
      w.show
      @lib2_update = w
    end
  end
end


#-------------------------------------------------------------------------------

if defined?( TT::Lib ) && TT::Lib.compatible?( '2.7.0', 'Drop Zone' )

module TT::Plugins::DropZone
  
  
  ### CONSTANTS ### ------------------------------------------------------------
  
  # Plugin information
  PLUGIN_ID       = 'TT_DropZone'.freeze
  PLUGIN_NAME     = 'Drop Zone'.freeze
  PLUGIN_VERSION  = TT::Version.new(1,0,0).freeze
  
  # Version information
  RELEASE_DATE    = '31 May 12'.freeze
  
  # Resource paths
  PATH_ROOT   = File.dirname( __FILE__ ).freeze
  PATH        = File.join( PATH_ROOT, PLUGIN_ID ).freeze
  PATH_UI     = File.join( PATH, 'UI' ).freeze
  
  
  ### VARIABLES ### ------------------------------------------------------------
  
  @wnd_drop_pad = nil
  @installed_stack = []
  
  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    # Commands
    cmd = UI::Command.new( 'Drop Zone' ) { self.toggle_dropzone_window }
    cmd.status_bar_text = 'Show or hide the DropZone window for installing plugins.'
    cmd.tooltip = 'Drop Zone'
    cmd.set_validation_proc { self.dropzone_window_validation_proc }
    cmd_toggle_dropzone_window = cmd

    # Menus
    m = TT.menu( 'Window' )
    m.add_item( cmd_toggle_dropzone_window )
  end 
  
  
  ### LIB FREDO UPDATER ### ----------------------------------------------------
  
  def self.register_plugin_for_LibFredo6
    {   
      :name => PLUGIN_NAME,
      :author => 'thomthom',
      :version => PLUGIN_VERSION.to_s,
      :date => RELEASE_DATE,   
      :description => 'Drag and Drop Ruby packages to install.',
      :link_info => 'http://sketchucation.com/forums/viewtopic.php?t=0'
    }
  end
  
  
  ### MAIN SCRIPT ### ----------------------------------------------------------
  
  # @return [Boolean]
  # @since 1.0.0
  def self.toggle_dropzone_window
    @wnd_drop_pad ||= self.create_dropzone_window
    if @wnd_drop_pad.visible?
      @wnd_drop_pad.close
      false
    else
      @wnd_drop_pad.show_window
      true
    end
  end


  # @return [Integer]
  # @since 1.0.0
  def self.dropzone_window_validation_proc
    if @wnd_drop_pad && @wnd_drop_pad.visible?
      MF_CHECKED
    else
      MF_UNCHECKED
    end
  end
  

  # @return [String]
  # @since 1.0.0
  def self.create_dropzone_window
    puts 'Creating Drop Zone Window...'
    options = {
      :title      => 'Drop Zone',
      :pref_key   => PLUGIN_ID,
      :scrollable => false,
      :resizable  => false,
      :width      => 400,
      :height     => 450,
      :left       => 200,
      :top        => 100
    }
    window = TT::GUI::Window.new( options )
    window.theme = TT::GUI::Window::THEME_GRAPHITE # (!) Make theme use IE-Edge
    window.add_script( File.join( 'file:///', PATH_UI, 'drop_zone.js' ) )
    window.add_style(  File.join( 'file:///', PATH_UI, 'window.css' ) )

    window.add_action_callback( 'Install_Files' ) { | dialog, params |
      puts '[Callback::Install_Files]'
      filename = self.install_file( params )
      @installed_stack << filename if filename
    }

    window.add_action_callback( 'Install_Complete' ) { | dialog, params |
      puts '[Callback::Install_Ended]'
      puts "> Checking installed stack: #{@installed_stack.length}"
      self.check_virtualstore( @installed_stack )
      @installed_stack.clear
    }
    
    window
  end


  # @parap [Array<String>] filenames
  #
  # @return [Boolean]
  # @since 1.0.0
  def self.check_virtualstore( filenames )
    puts "self.check_virtualstore"
    p filenames
    return false unless TT::System.is_windows?
    # Locate destination.
    destination = Sketchup.find_support_file( 'Plugins' )
    destination = File.expand_path( destination )
    # Locate VirtualStore path of 'destination'
    virtualstore = File.join( ENV['LOCALAPPDATA'], 'VirtualStore' )
    virtualpath = destination.split(':')[1]
    # Get list of all files trapped in VirtualStore
    in_store = filenames.select { |filename|
      path = File.dirname( filename )
      path = File.expand_path( path )
      path == destination && self.is_virtual?( filename )
    }
    # Check if files are stuck in VirtualStore, notify user.
    if in_store.empty?
      return false
    else
      message = ''
      message << "You do not have required access to the Plugins folder.\n"
      message << "Some of the files ended up in VirtualStore.\n"
      message << "Would you like #{PLUGIN_NAME} to copy the files to the correct location?.\n"
      message << "If you answer yes you will get a UAC prompt asking for your confirmation."
      result = UI.messagebox( message, MB_YESNO ) # YES (6) and NO (7)
      if result == IDNO
        message = ''
        message << "There are still files in the VirtualStore."
        message << "This might cause some plugins not to function properly."
        UI.messagebox( message )
        return false
      end
    end
    # Compile BAT script to copy files to correct folder.
    bat = File.join( TT::System.temp_path, 'dropzone_copy.bat' )
    File.open( bat, 'w' ) { |file|
      for filename in filenames
        basename = File.basename( filename )
        virtualfile = File.join( virtualstore, virtualpath, basename )
        # Paths must have backslashes.
        basename.tr!('/','\\')
        virtualfile.tr!('/','\\')
        # Files must be quotes with double quotes - not single.
        file.puts %|move "#{virtualfile}" "#{filename}"|
      end
    }
    # Run script with elevated rights.
    puts bat
    begin
      # http://www.devguru.com/technologies/vbscript/quickref/filesystemobject_movefile.html
      require 'win32ole'
      shell = WIN32OLE.new( 'Shell.Application' )
      shell.ShellExecute( bat, nil, nil, 'runas' )
    rescue LoadError => e
      message = "win32ole.so was not found. #{PLUGIN_NAME} could not move the files.\n"
      message << "\n"
      message << "Would you like to open a webpage where you can download win32ole.so?"
      result = UI.messagebox( message, MB_YESNO )
      if result == IDYES
        UI.openURL( 'http://sketchucation.com/forums/viewtopic.php?t=42732#p380121' )
      end
      return false
    end
    true
  end


  # @param [String] file
  #
  # @return [String,False]
  # @since 1.0.0
  def self.install_file( file )
    puts "Installing File: #{file}"

    # Determine if the file can be handled and where it should be extracted.
    filetype = file.split('.').last
    case filetype.downcase
    when 'rb', 'rbs'
      destination = Sketchup.find_support_file( 'Plugins' )
    when 'zip', 'rbz'
      destination = TT::System.temp_path
    else
      # (!) Notify webdialog of unsupported filetype.
      UI.beep
      puts "The file type #{filetype} is not handled by DropZone."
      return false
    end
    filename = File.join( destination, file )

    # (!) Update WebDialog

    puts '>'
    puts "> Destination:"
    puts "  > #{destination}"
    puts "  > Writable: #{File.writable?(destination).inspect}"
    puts '>'
    puts "> File:"
    puts "  > #{filename}"

    # Hack - Getting the data from the Ruby Bridge element.
    raw_data = @wnd_drop_pad.get_element_value('RUBY_bridge')

    # Example data:
    # data:image/jpeg;base64,<DATA>
    protocol, stream = raw_data.split(':')
    mime, encoded_data = stream.split(';')
    encoding, data64 = encoded_data.split(',')
    data = TT::Binary.decode64( data64 )

    # Extract files.
    File.open( filename, 'wb' ) { |f|
      data_length = f.write( data )
      puts "  > Wrote #{data_length} bytes"
    }

    puts 'Sending WebDialog Message...'
    p @wnd_drop_pad.call_script( 'DropPadWindow.debug', "#{file} Installed..." )
    puts '> Sent!'

    # Install files.
    case filetype.downcase
    when 'rb', 'rbs'
      # (!) Error catch
      # Sketchup::require currently doesn't throw an exception or error. Instead
      # it returns `false` on failure (already loaded, or load error) or `0`
      # upon success.
      #
      # (!) Should not try to load file until it's been verified to not be in 
      #     VirtualStore. Maybe just skip here if detected to be in VirtualStore
      #     and load it after it's been moved.
      unless Sketchup::load( filename )
      #unless Sketchup::require( filename )
        # (!) Notify webdialog
        puts "Notice: '#{file}' could not be loaded."
        @installed_stack << filename # Debug
        return false
      end
    when 'zip', 'rbz'
      begin
        Sketchup.install_from_archive( filename )
      rescue Interrupt => error
        # (!) Notify webdialog
        puts "Notice: User said 'no': " + error
        return false
      rescue Exception => error
        # (!) Notify webdialog
        puts "Error during unzip: " + error
        return false
      end
    end

    # (!) Update WebDialog with results
    return filename
  end


  # @param [String] file
  #
  # @return [boolean]
  # @since 1.0.0
  def self.is_virtual?( file )
    return false unless TT::System.is_windows?
    filename = File.basename( file )
    filepath = File.dirname( file )
    # Verify file exists.
    unless File.exist?( file )
      raise IOError, "The file '#{file}' does not exist."
    end
    # See if it can be found in virtual store.
    virtualstore = File.join( ENV['LOCALAPPDATA'], 'VirtualStore' )
    path = filepath.split(':')[1]
    virtualfile = File.join( virtualstore, path, filename )
    File.exist?( virtualfile )
  end

  
  ### DEBUG ### ----------------------------------------------------------------
  
  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::DropZone.reload
  #
  # @param [Boolean] tt_lib
  #
  # @return [Integer]
  # @since 1.0.0
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    if defined?( PATH ) && File.exist?( PATH )
      x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
        load file
      }
      x.length + 1
    else
      1
    end
  ensure
    $VERBOSE = original_verbose
  end

end # module TT::Plugins::DropZone

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------