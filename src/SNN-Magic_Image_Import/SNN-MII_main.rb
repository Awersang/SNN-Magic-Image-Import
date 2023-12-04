require_relative 'frame'

module MyExtension
  module Dialog
    def self.open_dialog
      html_path = File.join(__dir__, 'SNN-MII_dialog.html') # Updated HTML file name
      options = {
        dialog_title: 'SNN - Magic Image Import',
        style: UI::HtmlDialog::STYLE_DIALOG,
        width: 500,
        height: 750,
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_size(options[:width], options[:height])
      dialog.set_file(html_path)
      dialog.center

      dialog.add_action_callback('puts_callback') { |dialog, params|
        # Handle the callback from the HTML here
        params = JSON.parse(params)
        puts "Callback received with parameters2: #{params}"
      }
      # Define the callback for the "ok_callback"
      dialog.add_action_callback('ok_callback') { |action_context, data_json|
        # Parse the JSON data received from the HTML
        data = JSON.parse(data_json)

        puts('data loaded')
        # Extract the data from the data object
        selected_files = data['files']
        default_image_depth = data['depth'].to_i.mm
        text_size = data['text_size'].to_i.mm
        add_text = data['add_text']
        spacing = data['spacing'].to_i.mm
        table = data['table']
        frame_type = data['frame_type'].to_i
        default_frame_width = data['frame_width'].to_i.mm
        default_frame_depth = data['frame_depth'].to_i.mm
        add_frame_to_all = data['add_frame_to_all']


        # Handle the data as needed
        puts "Selected Files: #{selected_files}"
        puts "Depth Value: #{default_image_depth}"
        puts "Text Size: #{text_size}"
        puts "Add Text: #{add_text}"
        puts "Spacing: #{spacing}"
        puts "Table : #{table}"


        # check for existance of relevant layers
        MyExtension.check_layers(['frames', 'images', 'names', 'art'])

        #check if table is empty
        if table.nil?
          MyExtension.import_images_from_files(selected_files, default_image_depth, text_size, add_text, spacing, frame_type, default_frame_width, default_frame_depth, add_frame_to_all)
        else
          MyExtension.import_images_from_table(table, default_image_depth, text_size, add_text, spacing)
        end
        # Close the dialog if needed
        dialog.close
      }
      dialog.add_action_callback('cancel_callback') { |action_context, _|
        # Handle the cancel action here (e.g., close the dialog)
        dialog.close
      }
      dialog.show
    end
  end


  def self.check_layers(layers_names)
    # checks if the layers in layers_names exist and creates them if they dont.
    layers_names.each do |layer_name|
      layer = Sketchup.active_model.layers[layer_name]
      if layer.nil?
        layer = Sketchup.active_model.layers.add(layer_name)
      end
    end
  end

  def self.import_images_from_files(image_files, default_image_depth, text_size, add_text, spacing, frame_type, default_frame_width, default_frame_depth, add_frame_to_all)
    puts('importing images')
    entities  = Sketchup.active_model.entities
    current_x = 0.mm
    bottom_offset = 30.mm

    image_files.each do |image_file|
      # Extract image image and frame dimensions from the filename
      # image dimensions are in the format " widthxheightxdepth "
      # frame dimensions are in the format "(widthxheightxdepth)"
      # depth is optional for both image and frame

      # Extract the image dimensions
      image_dimensions = image_file.match(/(?<!\()\b(\d+)x(\d+)(x(\d+))?\b(?!x|\))/)
      # if there is a match, extract the dimensions
      if image_dimensions
        width = image_dimensions[1].to_i.mm
        height = image_dimensions[2].to_i.mm
        depth = image_dimensions[4] ? image_dimensions[4].to_i.mm : default_image_depth
      end

      # Extract the frame dimensions
      frame_dimensions = image_file.match(/\((\d+)x(\d+)(x(\d+))?\)/)
      # if there is a match, extract the dimensions
      if frame_dimensions
        frame_width = frame_dimensions[1].to_i.mm
        frame_height = frame_dimensions[2].to_i.mm
        frame_depth = frame_dimensions[4] ? frame_dimensions[4].to_i.mm : default_frame_depth
      end


      if image_dimensions
        # Import the image
        image = entities.add_image(image_file, [current_x, -height / 2, depth], width, height)
        spacing_width = width
        # add the image to the images layer
        image.layer = Sketchup.active_model.layers['images']
        
        # Create a box under the image
        box = build_box(entities, image, depth)
        # add the box to the images layer        
        box.layer = Sketchup.active_model.layers['images']

        # Add text object with the file name (without extension) if add_text is true
        if add_text
          text_group = addNameText(entities, File.basename(image_file, '.*'), text_size, current_x, -height / 2 + bottom_offset, depth, width)
          # add the text to the names layer
          text_group.layer = Sketchup.active_model.layers['names']
        end

        # Frmae Logic
        # if frame type is larger than 0, add a frame
        if frame_type > 0
          # if there is a name match
          if frame_dimensions
            frame = build_frame(frame_width, frame_height, frame_depth, width, height, depth, frame_type, current_x,)
            spacing_width = frame_width
          #  if add_frame_to_all is true
          elsif add_frame_to_all
            frame = build_frame(width + 2 * default_frame_width, height + 2 * default_frame_width, default_frame_depth, width, height, depth, frame_type, current_x)
            spacing_width = width + 2 * default_frame_width
          end
        end

        # if frame exisits add the frame to frames layer
        if frame
          frame.layer = Sketchup.active_model.layers['frames']
        end

        # Group the image, box, and text and frame together if they exist
        if frame && text_group
          image_group = entities.add_group([image, box, text_group, frame])
        elsif frame
          image_group = entities.add_group([image, box, frame])
        elsif text_group
          image_group = entities.add_group([image, box, text_group])
        else
          image_group = entities.add_group([image, box])
        end

        # add the image group to the art layer
        image_group.layer = Sketchup.active_model.layers['art']

      else
        # if there is no match, skip the image
        puts "No image dimensions found in #{image_file}"
      end
                      



      # Increment the x position for the next image
      current_x += spacing_width + spacing

      Sketchup.active_model.commit_operation
      puts 'import completed'


    end
  end

  def self.import_images_from_table(table, image_depth, text_size, add_text, spacing)
    entities  = Sketchup.active_model.entities
    current_x = 0.mm
    bottom_offset = 30.mm

    #iterate through the table
    table.each do |row|
      width = row[1][1].to_i.mm
      height = row[1][2].to_i.mm

      # Import the image
      image = entities.add_image(row[0], [current_x, 0, image_depth], width, height)

      # Create a bounding box around the image
      box = build_box(entities, image, image_depth)

      # Add text object with the file name (without extension) if add_text is true
      if add_text
        text_group = addNameText(entities, File.basename(row[0], '.*'), text_size, current_x, bottom_offset, image_depth, width)
        # Group the image, box, and text together
        image_group = entities.add_group([image, box, text_group])
      else
        # Group the image and box together
        image_group = entities.add_group([image, box])
      end

      # Increment the x position for the next image
      current_x += width + spacing

      Sketchup.active_model.commit_operation
      puts 'import completed'

    end
  end

  def self.build_box(entities, image, image_depth)
    # Create a bounding box around the image
    box = entities.add_group
    bb = image.bounds
    box_corners = [
      [bb.min.x, bb.min.y, 0],
      [bb.max.x, bb.min.y, 0],
      [bb.max.x, bb.max.y, 0],
      [bb.min.x, bb.max.y, 0]
    ]
    face = box.entities.add_face(box_corners)
    face.pushpull(-image_depth)

    # Remove the top face of the box
    top_face = box.entities.grep(Sketchup::Face).find { |f| f.normal.z == 1 }
    top_face.erase! if top_face

    return box
  end

  def self.addNameText(entities, text_string, text_size, current_x, bottom_offset, image_depth, width)
    # Add a 3d text object with the file name (without extension)
    text_group = entities.add_group
    text_group.entities.add_3d_text(text_string, TextAlignCenter, "Arial", text_size)

    # Split text into lines shorter than the image width minus 10mm
    text_width = text_group.bounds.width
    max_text_width = width - 15.mm
    if text_width > max_text_width
      # Calculate the average letter width
      letter_width = text_width / text_string.length

      # Estimate how many letters should be in one line
      letters_per_line = (max_text_width / letter_width).to_i

      # Split the text string into lines
      lines = []
      current_line = ""
      words = text_string.split(" ")
      words.each do |word|
        if current_line.empty?
          current_line = word
        elsif current_line.length + word.length + 1 > letters_per_line
          lines << current_line
          current_line = word
        else
          current_line += " " + word
        end
      end
      lines << current_line unless current_line.empty?
      text_string = lines.join("\n")
      text_group.erase!
      text_group = entities.add_group
      text_group.entities.add_3d_text(text_string, TextAlignCenter, "Arial", text_size)
    end

    # Position the text in center horizontally and offset from the bottom of the image by a given amount
    text_width = text_group.bounds.width
    text_position = [
      current_x + (width - text_width) / 2,
      bottom_offset,
      image_depth
    ]
    transformation = Geom::Transformation.translation(text_position) 
    text_group.transform!(transformation)

    # Color the text white
    text_group.material = Sketchup::Color.new(255, 255, 255)

    # Return the text group
    return text_group
  end

  unless file_loaded?(__FILE__)
    menu = UI.menu('Plugins').add_item('SNN - Magic Image Import') {
      Dialog.open_dialog # Open the dialog when the menu item is clicked
    }
    file_loaded(__FILE__)
  end
end
