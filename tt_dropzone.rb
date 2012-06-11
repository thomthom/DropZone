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
  timer = UI.start_timer( 0, false ) {
    UI.stop_timer( timer )
    filename = File.basename( __FILE__ )
    message = "#{filename} require TT_Lib² to be installed.\n"
    message << "\n"
    message << "Would you like to open a webpage where you can download TT_Lib²?"
    result = UI.messagebox( message, MB_YESNO )
    if result == 6 # YES
      UI.openURL( 'http://www.thomthom.net/software/tt_lib2/' )
    end
  }
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
  PATH        = File.join( PATH_ROOT, 'TT_DropZone' ).freeze
  PATH_UI     = File.join( PATH, 'UI' ).freeze
  
  
  ### VARIABLES ### ------------------------------------------------------------
  
  @wnd_attributes = nil
  
  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    # Menus
    m = TT.menu( 'Window' )
    m.add_item( 'Drop Zone' ) { self.toggle_dropzone_window }
    
    # Toolbar
    #toolbar = UI::Toolbar.new( PLUGIN_NAME )
    #toolbar.add_item( ... )
    #if toolbar.get_last_state == TB_VISIBLE
    #  toolbar.restore
    #  UI.start_timer( 0.1, false ) { toolbar.restore } # SU bug 2902434
    #end
  end 
  
  
  ### LIB FREDO UPDATER ### ----------------------------------------------------
  
  def self.register_plugin_for_LibFredo6
    {   
      :name => PLUGIN_NAME,
      :author => 'thomthom',
      :version => PLUGIN_VERSION.to_s,
      :date => RELEASE_DATE,   
      :description => 'Drag and Drop Ruby packages to install.',
      :link_info => 'http://forums.sketchucation.com/viewtopic.php?f=0&t=0'
    }
  end
  
  
  ### MAIN SCRIPT ### ----------------------------------------------------------
  
  # @return [String]
  # @since 1.0.0
  def self.toggle_dropzone_window
    # (!) Implement toggle.
    @wnd_drop_pad ||= self.create_dropzone_window
    if @wnd_drop_pad.visible?
      @wnd_drop_pad.bring_to_front
    else
      @wnd_drop_pad.show_window
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
      self.install_file( params )
    }
    
    window
  end

  # @return [String]
  # @since 1.0.0
  def self.install_file( file )
    puts "Installing File: #{file}"

    destination = Sketchup.find_support_file( 'Plugins' )
    destination = 'C:/Users/Thomas/Desktop/DropZone' # (!) DEBUG
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

    # Install files.
    # * rbz,zip Write to temp, install_rbz_archive
    # * rb, rbs Write directly to plugin folder
    File.open( filename, 'wb' ) { |file|
      data_length = file.write( data )
      puts "  > Wrote #{data_length} bytes"
    }

    # (!) Update WebDialog with results
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
    x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
      load file
    }
    x.length
  ensure
    $VERBOSE = original_verbose
  end

end # module TT::Plugins::DropZone

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------