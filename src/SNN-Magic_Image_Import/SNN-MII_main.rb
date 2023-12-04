module MyExtension
  module Dialog
    def self.open_dialog
      html_path = File.join(__dir__, 'SNN-MII_dialog.html') # Updated HTML file name
      options = {
        dialog_title: 'SNN - Magic Image Import',
        style: UI::HtmlDialog::STYLE_DIALOG,
        width: 600,
        height: 520,
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_size(options[:width], options[:height])
      dialog.set_file(html_path)
      dialog.center

      dialog.add_action_callback('puts_callback') { |dialog, params|
        # Handle the callback from the HTML here
        puts("Callback received with parameters2: #{params}")
      }
      # Define the callback for the "ok_callback"
      dialog.add_action_callback('ok_callback') { |action_context, data_json|
        # Parse the JSON data received from the HTML
        data = JSON.parse(data_json)

        puts('data loaded')
        # Extract the data from the data object
        selected_files = data['files']
        depth_value = data['depth'].to_i.mm
        text_size = data['text_size'].to_i.mm
        add_text = data['add_text']
        spacing = data['spacing'].to_i.mm
        table = data['table']


        # Handle the data as needed
        puts "Selected Files: #{selected_files}"
        puts "Depth Value: #{depth_value}"
        puts "Text Size: #{text_size}"
        puts "Add Text: #{add_text}"
        puts "Spacing: #{spacing}"
        puts "Table : #{table}"

        #check if table is empty
        if table.nil?
          MyExtension.importImagesFromFiles(selected_files, depth_value, text_size, add_text, spacing)
        else
          MyExtension.importImagesFromTable(table, depth_value, text_size, add_text, spacing)
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


  def self.importImagesFromFiles(image_files, box_height, text_size, add_text, spacing)
    puts('importing images')
    entities  = Sketchup.active_model.entities
    current_x = 0.mm
    bottom_offset = 30.mm

    image_files.each do |image_file|
      # Extract image dimensions from the filename (assuming format: "widthXheight")
      match = File.basename(image_file).match(/(\d+)x(\d+)/)
      if match
        puts('importing image', image_file)
        width = match[1].to_i.mm
        height = match[2].to_i.mm

        puts('widthhhhhh', width)
        puts('heightttttt', height)

        # Import the image
        image = entities.add_image(image_file, [current_x, 0, box_height], width, height)

        # Create a bounding box around the image
        box = buildBox(entities, image, box_height)

        frame = buildFrame(entities, box_height, frame_depth, width, height, frame_width, frame_height)

        # Add text object with the file name (without extension) if add_text is true
        if add_text
          text_group = addNameText(entities, File.basename(image_file, '.*'), text_size, current_x, bottom_offset, box_height, width)
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
  end


  def self.importImagesFromTable(table, box_height, text_size, add_text, spacing)
    entities  = Sketchup.active_model.entities
    current_x = 0.mm
    bottom_offset = 30.mm

    #iterate through the table
    table.each do |row|
      width = row[1][1].to_i.mm
      height = row[1][2].to_i.mm

      # Import the image
      image = entities.add_image(row[0], [current_x, 0, box_height], width, height)

      # Create a bounding box around the image
      box = buildBox(entities, image, box_height)

      # Add text object with the file name (without extension) if add_text is true
      if add_text
        text_group = addNameText(entities, File.basename(row[0], '.*'), text_size, current_x, bottom_offset, box_height, width)
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

  def self.buildBox(entities, image, box_height)
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
    face.pushpull(-box_height)

    # Remove the top face of the box
    top_face = box.entities.grep(Sketchup::Face).find { |f| f.normal.z == 1 }
    top_face.erase! if top_face

    return box
  end

def self.buildFrame(entities, box_height, frame_depth, width, height, frame_width, frame_height)
  # Creates a frame around the Box, the internal dimensions maches the box the external dimensions are defined by the frame_width and frame_height.
  # The frame internal depth is matching the box height. And the frame external depth is defined by the frame_depth.
  # The frame is centered on the box.
  frame = entities.add_group
  frame_corners = [
    [-(frame_width/2), -(frame_height/2), 0],
    [-(frame_width/2), (frame_height/2), 0],
    [(frame_width/2), (frame_height/2), 0],
    [(frame_width/2), -(frame_height/2), 0]
  ]
  face = frame.entities.add_face(frame_corners)
  face.pushpull(-box_height)
  face.pushpull(frame_depth)
  # Remove the top face of the frame
  top_face = frame.entities.grep(Sketchup::Face).find { |f| f.normal.z == 1 }
  top_face.erase! if top_face

  # Position the frame in center horizontally and offset from the bottom of the image by a given amount
  frame_position = [
    (width/2),
    (height/2),
    box_height
  ]
  transformation = Geom::Transformation.translation(frame_position) 
  frame.transform!(transformation)

  # Color the frame
  frame.material = Sketchup::Color.new(0, 0, 0)

  return frame
end




  def self.addNameText(entities, text_string, text_size, current_x, bottom_offset, box_height, width)
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
      box_height
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
