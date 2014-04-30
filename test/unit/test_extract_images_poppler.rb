here = File.expand_path(File.dirname(__FILE__))
require File.join(here, '..', 'test_helper')

class ExtractImagesTest < Test::Unit::TestCase
  def test_basic_image_extraction
    extractor.extract('test/fixtures/obama_arts.pdf', :format => :png, :size => "250x", :output => OUTPUT)
    assert_directory_contains(OUTPUT, ['obama_arts-1.png', 'obama_arts-2.png'])
  end

  def test_image_formatting
    extractor.extract('test/fixtures/obama_arts.pdf', :format => [:jpg, :png], :size => "250x", :output => OUTPUT)
    assert Dir["#{OUTPUT}/*.png"].length == 2
    assert Dir["#{OUTPUT}/*.jpg"].length == 2
  end

  # def test_page_ranges
  #   extractor.extract('test/fixtures/obama_arts.pdf', :format => :jpg, :size => "50x", :pages => 2, :output => OUTPUT)
  #   assert Dir["#{OUTPUT}/*.jpg"] == ["#{OUTPUT}/obama_arts-2.jpg"]
  # end

  # def test_image_sizes
  #   extractor.extract('test/fixtures/obama_arts.pdf', :format => :jpg, :rolling => true, :size => ["150x", "50x"], :output => OUTPUT)
  #   assert File.size("#{OUTPUT}/50x/obama_arts-1.jpg") < File.size("#{OUTPUT}/150x/obama_arts-1.jpg")
  # end

  def test_encrypted_images
    extractor.extract('test/fixtures/encrypted.pdf', :format => :jpg, :size => "50x", :output => OUTPUT)
    assert File.size("#{OUTPUT}/encrypted-1.jpg") > 100
  end

  def test_password_protected_extraction
    assert_raises(ExtractionFailed) do
      extractor.extract('test/fixtures/completely_encrypted.pdf', {})
    end
  end

  def test_repeated_extraction_in_the_same_directory
    extractor.extract('test/fixtures/obama_arts.pdf', :format => :jpg, :size => "250x", :output => OUTPUT)
    assert_directory_contains(OUTPUT, ['obama_arts-1.jpg', 'obama_arts-2.jpg'])
    extractor.extract('test/fixtures/obama_arts.pdf', :format => :jpg, :size => "250x", :output => OUTPUT)
    assert_directory_contains(OUTPUT, ['obama_arts-1.jpg', 'obama_arts-2.jpg'])
  end

  def test_name_escaping_while_extracting_images
    extractor.extract('test/fixtures/PDF file with spaces \'single\' and "double quotes".pdf', :format => :jpg, :size => "250x", :output => OUTPUT)
    assert_directory_contains(OUTPUT, ['PDF file with spaces \'single\' and "double quotes"-1.jpg',
                                       'PDF file with spaces \'single\' and "double quotes"-1.jpg'])
  end

  def extractor
    @extractor ||= Docsplit::PopplerImageExtractor.new
  end

end
