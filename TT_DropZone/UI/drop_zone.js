var DropPadWindow = function() {
  return {
  
  
    init : function() {
      var $html = $('html');
      var $body = $('body');
      var $zone = $('<div id="zone">Drop Files Here</div>');
      
      $body.append( $zone );
      $body.append( $('<div id="list"></div>') );
      
      // Check the File API support
      if ( window.File && window.FileReader && window.FileList && window.Blob ) {
        $html.on( 'drop',      handleFileDrop );
        $html.on( 'dragover',  handleDragOver );
        $html.on( 'dragenter', handleDragEnter );
        //$html.on( 'dragleave', handleDragLeave );

        $body.append( $('<div class="message">File API Supported :)</div>') );
      }
      else {
        // http://caniuse.com/fileapi
        $html.addClass( 'invalid' );

        $html.on( 'drop',      handleInvalidDrop );
        $html.on( 'dragover',  handleInvalidDrag );
        $html.on( 'dragenter', handleInvalidDragEnter );
        //$html.on( 'dragleave', handleDragLeave );
        
        // Safari returns 'Netscape' as navigator.appName,
        // IE returns Microsoft Internet Explorer
        var browser = navigator.appName;
        if ( navigator.userAgent.indexOf('AppleWebKit') > -1) {
          browser = 'Safari';
        }
        
        var $message = $('<div class="message error"/>');
        $message.html(
          '<span class="emo">&#x2639;</span>' +
          '<p><b>File API not supported!</b></p>' + 
          '<p>Please upgrade ' + browser + '.</p>'
        );
        $body.append( $message );
      }

      // Drag Leave Event - must use a hidden overlay element.
      var $dragCatcher = $('<div id="dragcatcher"/>');
      $dragCatcher.on( 'dragleave', handleDragLeave );
      $('body').append( $dragCatcher );
    }
    
    
  };
  
  /* PRIVATE */
  
  function handleFileDrop( event ) {
    event.stopPropagation();
    event.preventDefault();

    var files = event.originalEvent.dataTransfer.files; // FileList object.

    // Create UI
    var $ul = $('<ul/>');
    for ( var i = 0, f; f = files[i]; i++ ) {
      name = escape(f.name);
      type = f.type || 'n/a';
      size = f.size;
      date = f.lastModifiedDate;
      date = ( date ) ? date.toLocaleDateString() : 'n/a';
      $ul.append(
        $('<li><strong>' + name + '</strong><br/>' +
          size + ' bytes - ' + '(' + type + ')<br/>' + 
          'Last Modified: ' + date + '</li>') );
    }
    $('#list').html( $ul );
    $('#zone').removeClass('drag');
    $('#dragcatcher').hide();

    // Process Files
    for ( var i = 0, f; f = files[i]; i++ ) {
      var reader = new FileReader();
      reader.onload = (function(file) {
        return function(e) {
          data = e.target.result;
          // Hack, put data in Ruby Bridge element because data is too large.
          $('#RUBY_bridge').val( data );
          window.location = 'skp:Install_Files@' + file.name;
        };
      })(f);
      reader.readAsDataURL(f);
    }
  }

  function handleDragOver( event ) {
    event.stopPropagation();
    event.preventDefault();
    event.originalEvent.dataTransfer.dropEffect = 'copy';
  }

  function handleDragEnter( event ) {
    event.stopPropagation();
    event.preventDefault();
    event.originalEvent.dataTransfer.dropEffect = 'copy';
    $('#zone').addClass('drag');
    $('#dragcatcher').show();
  }

  function handleDragLeave( event ) {
    event.stopPropagation();
    event.preventDefault();
    $('#zone').removeClass('drag');
    $('#dragcatcher').hide();
  }

  function handleInvalidDrop( event ) {
    event.stopPropagation();
    event.preventDefault();
    event.originalEvent.dataTransfer.dropEffect = 'none';
    $('#zone').removeClass('drag');
    $('#dragcatcher').hide();
  }

  function handleInvalidDrag( event ) {
    event.stopPropagation();
    event.preventDefault();
    event.originalEvent.dataTransfer.dropEffect = 'none';
  }

  function handleInvalidDragEnter( event ) {
    event.stopPropagation();
    event.preventDefault();
    event.originalEvent.dataTransfer.dropEffect = 'none';
    $('#zone').addClass('drag');
    $('#dragcatcher').show();
  }
  
}(); // DropPadWindow

$(document).ready( DropPadWindow.init );