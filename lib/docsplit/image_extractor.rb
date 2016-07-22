module Docsplit

  # Delegates to GraphicsMagick in order to convert PDF documents into
  # nicely sized images.
  class ImageExtractor

    MEMORY_ARGS     = "-limit memory 256MiB -limit map 512MiB"
    DEFAULT_FORMAT  = :png
    DEFAULT_DENSITY = '150'

    attr_reader :output, :pages, :density, :formats, :sizes, :rolling

    alias_method :rolling?, :rolling

    # Extract a list of PDFs as rasterized page images, according to the
    # configuration in options.
    def extract(pdfs, options)
      extract_options(options)
      [pdfs].flatten.each do |pdf|
        previous = nil
        sizes.each_with_index do |size|
          formats.each do |format|
            convert(pdf, size, format, previous)
          end
          previous = size if rolling?
        end
      end
    end

    # Convert a single PDF into page images at the specified size and format.
    # If `--rolling`, and we have a previous image at a larger size to work with,
    # we simply downsample that image, instead of re-rendering the entire PDF.
    # Now we generate one page at a time, a counterintuitive opimization
    # suggested by the GraphicsMagick list, that seems to work quite well.
    def convert(pdf, size, format, previous = nil)
      tempdir   = Dir.mktmpdir
      basename  = File.basename(pdf, File.extname(pdf))
      directory = directory_for(size)
      pages     = @pages || '1-' + Docsplit.extract_length(pdf).to_s
      escaped_pdf = ESCAPE[pdf]
      FileUtils.mkdir_p(directory) unless File.exists?(directory)
      common    = "#{MEMORY_ARGS} -density #{@density} #{resize_arg(size)} #{quality_arg(format)}"

      if previous
        FileUtils.cp(Dir[directory_for(previous) + '/*'], directory)
        result = `MAGICK_TMPDIR=#{tempdir} OMP_NUM_THREADS=2 gm mogrify #{common} -unsharp 0x0.5+0.75 \"#{directory}/*.#{format}\" 2>&1`.chomp
        raise ExtractionFailed, result if $? != 0
      else
        page_list(pages).each do |page|
          out_file  = ESCAPE[File.join(directory, "#{basename}_#{page}.#{format}")]
          cmd = "MAGICK_TMPDIR=#{tempdir} OMP_NUM_THREADS=2 gm convert +adjoin -define pdf:use-cropbox=true #{common} #{escaped_pdf}[#{page - 1}] #{out_file} 2>&1".chomp
          result = `#{cmd}`.chomp
          raise ExtractionFailed, result if $? != 0
        end
      end
    ensure
      FileUtils.remove_entry_secure tempdir if File.exists?(tempdir)
    end

    private

    # Extract the relevant GraphicsMagick options from the options hash.
    def extract_options(options)
      @output  = options[:output]  || '.'
      @pages   = options[:pages]
      @density = options[:density] || DEFAULT_DENSITY
      @formats = [options[:format] || DEFAULT_FORMAT].flatten
      @sizes   = [options[:size]].flatten.compact
      @sizes   = [nil] if @sizes.empty?
      @rolling = !!options[:rolling]
    end

    # If there's only one size requested, generate the images directly into
    # the output directory. Multiple sizes each get a directory of their own.
    def directory_for(size)
      path = @sizes.length == 1 ? @output : File.join(@output, size)
      File.expand_path(path)
    end

    def ensure_directory_for(size)
      directory_for(size).tap do |dir|
        FileUtils.mkdir_p(dir) unless File.exists?(dir)
      end
    end

    # Generate the resize argument.
    def resize_arg(size)
      size.nil? ? '' : "-resize #{size}"
    end

    # Generate the appropriate quality argument for the image format.
    def quality_arg(format)
      case format.to_s
      when /jpe?g/ then "-quality 85"
      when /png/   then "-quality 100"
      else ""
      end
    end

    # Generate the expanded list of requested page numbers.
    def page_list(list_string = self.pages)
      list_string.to_s.split(',').map do |range|
        if range.include?('-')
          range = range.split('-')
          Range.new(range.first.to_i, range.last.to_i).to_a.map { |n| n.to_i }
        else
          range.to_i
        end
      end.flatten.uniq.grep(Integer).sort
    end

    def uses_page_ranges?(list_string = self.pages)
      page_list(list_string).any?
    end

    def each_page_range(list_string = self.pages)
      return enum_for(__method__, list_string) unless block_given?

      list_string  = Array(list_string).join(',')
      page_numbers = page_list(list_string)

      if page_numbers.empty?
        # 1 .. -1 means "all pages" here
        yield(1, -1)
      else
        start = finish = page_numbers.first

        page_numbers.each_cons(2) do |left, right|
          next_in_seq = left + 1
          if right <= next_in_seq
            finish = right
          else
            yield(start, finish)
            start = finish = right
          end
        end

        yield(start, finish)
      end

      page_numbers
    end
  end

end
