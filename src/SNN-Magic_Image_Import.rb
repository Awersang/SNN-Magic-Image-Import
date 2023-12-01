require 'sketchup.rb'
require 'extensions.rb'


SKETCHUP_CONSOLE.show

module Examples
  module HelloCube
    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('SNN-Magic_Image_Import', 'SNN-Magic_Image_Import/SNN-MII_main')
      ex.description = 'batch import and resize images'
      ex.version     = '1.0.0'
      ex.copyright   = 'Trimble Navigations © 2016'
      ex.creator     = 'Tomasz Swietlik'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end
  end # module HelloCube
end # module Examples