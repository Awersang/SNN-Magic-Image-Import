

def divide_lines(lines, divisions)
    # Initialize an array to store the vertices
    vertices = []

    # Add the start points of the lines to the vertices array
    vertices << lines.map { |line| line.start.position }

    # Divide the lines according to the divisions array
    divisions.each do |division|
        vertices << lines.map do |line|
            start_point = line.start.position
            end_point = line.end.position
            vector = end_point - start_point
            division_point = start_point + vector.transform(division)
            division_point
        end
    end
    # Add the end points of the lines to the vertices array
    vertices << lines.map { |line| line.end.position }

    vertices
end

def create_lines_from_points(object, points)
    # Initialize an array to store the lines
    lines = []

    # Create lines from each pair of points
    points.each_cons(2) do |start_point, end_point|
        lines << object.entities.add_line(start_point, end_point)
    end

    # Connect the last point to the first
    lines << object.entities.add_line(points.last, points.first)

    lines
end

def create_lines_from_points_arrays(object, points_arrays)
    # Initialize an array to store the lines arrays
    lines_arrays = []

    # Create lines from each array of points
    points_arrays.each do |points|
        lines_arrays << create_lines_from_points(object, points)
    end

    lines_arrays
end

def move_profiles_up(frame, profiles, distances)
    # Prepare the arrays for the transform_by_vectors method
    to_move = []
    vectors = []

    # Fill the arrays with the unique vertices and the corresponding vectors
    profiles.each_with_index do |profile, index|
        # Get the unique vertices from the profile
        vertices = profile.is_a?(Array) ? profile.flat_map { |line| [line.start, line.end] }.uniq : [profile.start, profile.end]

        # Add each vertex and its corresponding vector to the arrays
        vertices.each do |vertex|
            to_move << vertex
            vectors << Geom::Vector3d.new(0, 0, distances[index].mm)
        end
    end

    # Apply the transformations
    frame.entities.transform_by_vectors(to_move, vectors)

    frame
end

def draw_base_frame(entities, fw,fh,w,h,d)
    # Create a new group for the outer square
    frame = entities.add_group
    outer_face = frame.entities.add_face([0, 0, 0], [fw, 0, 0], [fw, fh, 0], [0, fh, 0])

    # Create the inner square hole
    inner_face = frame.entities.add_face([fw / 2 - w / 2, fh / 2 - h / 2, 0], [fw / 2 + w / 2, fh / 2 - h / 2, 0], [fw / 2 + w / 2, fh / 2 + h / 2, 0], [fw / 2 - w / 2, fh / 2 + h / 2, 0])

    # Get the vertices of the inner square before erasing it
    inner_vertices = inner_face.vertices.map(&:position)

    # Create the hole
    inner_face.erase!

    # Push the face up by 20mm
    outer_face.pushpull(d)

    # Get the new top face
    top_face = frame.entities.grep(Sketchup::Face).find { |f| f.normal.z > 0 }

    # Get the vertices of the top face
    top_vertices = top_face.outer_loop.vertices

    # Get the vertices of the hole
    hole_vertices = top_face.loops[1].vertices

    # reverse the order of the vertices of the hole
    hole_vertices.reverse!

    # change the order of the vertices of the hole, 2, 3, 0, 1
    hole_vertices.rotate!(2)

    # Connect the corresponding vertices with lines and store them in an array
    lines = top_vertices.each_with_index.map do |vertex, index|
        frame.entities.add_line(hole_vertices[index].position, vertex.position)
    end

    # # Pass the lines to the divide_lines function
    # vertices = divide_lines(frame,lines, [5, 5])

    puts("lines", lines)

    # # Connect the corresponding vertices with lines and store them in an array
    # lines = top_vertices.each_with_index.map do |vertex, index|
    #     frame.entities.add_line(vertex.position, hole_vertices[index].position)
    # end
    
    return frame, lines
end

def shape_the_frame(frame, lines, distances, divisions)
    
    # Divide the lines according to the divisions array
    vertices = divide_lines(lines, divisions)

    # Create the profiles
    profiles = create_lines_from_points_arrays(frame, vertices)
    
    # Shape the profiles
    frame = move_profiles_up(frame, profiles, distances)

    return frame, profiles
end

def build_frame(fw,fh,fd,w,h,d, type)

    model = Sketchup.active_model
    entities = model.active_entities

    # Start a new operation
    model.start_operation("Draw Frame", true)

    # Define the frame types
    frame_types = {
        1 => {distances: [0, 30], divisions: []},
        2 => {distances: [0.0, 0.1, 0.0, 1.0, 1.0], divisions: [0.05, 0.1, 0.9]},
        3 => {distances: [0.0, 0.066, 0.083, 0.066, 0.0, 0.1, 0.133, 0.1, 0.0, 0.0, 0.166, 0.46, 0.86, 1.0, 1.0],
            divisions: [0.01, 0.035, 0.06,   0.07, 0.1, 0.135, 0.17, 0.2,   0.4, 0.59, 0.77, 0.89, 0.9]}
    }

    # Get the distances and divisions from the frame types
    distances = frame_types[type][:distances].map { |distance| distance * (fd-d).to_mm }
    divisions = frame_types[type][:divisions]
    # puts("distances", distances)

    # puts(fd, d, fd-d,(fd-d).mm)
    # puts((fd-d).mm)

    # z equals fd minus d
 

    # Draw the base frame
    frame, lines = draw_base_frame(entities, fw,fh,w,h,d)
    
    # Shape the frame
    frame, profiles = shape_the_frame(frame, lines, distances, divisions)

    # soften all profiles but first and the last
    profiles[1..-2].each do |profile|
        profile.each do |line|
            line.soft = true
        end
    end

    model.commit_operation

    frame
end

model = Sketchup.active_model
entities = model.active_entities
# # clear the model
entities.clear!

# Define the dimensions of the outer square
fw = 600.mm
fh = 700.mm
fd = 100.mm

# Define the dimensions of the inner square
w = 500.mm
h = 500.mm
d = 20.mm

# Define the frame type (1, 2, or 3)
type = 3

build_frame(fw,fh,fd,w,h,d, type)

