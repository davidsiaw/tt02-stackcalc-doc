require 'yaml'

class Nicedoc
  def initialize(contents)
    @contents = contents
  end

  def yaml
    YAML.load(@contents.split("---").first)
  end

  def renderer
    NicedocRenderer.new(@contents.split("---", 2).last)
  end
end

class Span
  attr_reader :type, :line
  def initialize(line, type=:normal)
    @type = type
    @line = line
  end

  TYPES = [
    ['**', :bold],
    ['*', :italic],
    ['__', :underline],
    ['^^', :overline],
    ['--', :strikeout]
  ]

  def innerspans
    TYPES.each do |delim, curtype|
      toks = @line.split(delim)
  
      if toks.length > 2 && (toks.length & 1) == 1
        return toks.each_with_index.map do |x, i|
          odd = i & 1 == 1
          s = Span.new(x, odd ? curtype : @type)
          s = s.innerspans || s
        end
      end
    end
    nil
  end

  def generate(context)
    spanlist = innerspans&.flatten
    line = @line
    context.instance_exec do
      if spanlist.nil?
        span line
      else
        spanlist.each do |x|
          span x.line, class: "n_#{x.type}"
        end
      end
      span ' '
    end
  end
end


class Block
  attr_reader :type, :lines

  def initialize(type:, lines:)
    @type = type
    @lines = lines
  end

  def spans
    lines.map {|x| Span.new(x)}
  end

  def generate(context)
    spanlist = spans
    spanlist.each do |span|
      span.generate(context)
    end
  end

  def to_s
    @lines.join(' ')
  end
end

class NicedocRenderer
  def initialize(contents)
    @contents = contents
  end

  def generate(context)
    contents = @contents

    blocks = []
    superblocks = []

    contents.split(/\n\n+/).select {|x| x.length != 0}.each do |blk|
      if blk.start_with?('#')
        superblocks << blocks if blocks.length != 0
        blocks = []

        blocks << Block.new(
          type: :header,
          lines: blk.split("\n")
        )
      elsif blk.start_with?('*note*')
        superblocks << blocks[0..-2]
        blocks = [blocks[-1]]

        blocks << Block.new(
          type: :note,
          lines: blk.split("\n")
        )
      elsif blk.start_with?(/\+(\-+\+)+/)
        blocks << Block.new(
          type: :table,
          lines: blk.split("\n")
        )
      elsif blk.start_with?('- ')
        blocks << Block.new(
          type: :ul,
          lines: blk.split("\n")
        )
      elsif blk.start_with?('--')
        blocks << Block.new(
          type: :hr,
          lines: []
        )
      elsif blk.start_with?(/  [^ ]/)
        blocks << Block.new(
          type: :paragraph,
          lines: blk.split("\n")
        )
      else
        blocks << Block.new(
          type: :ordinary,
          lines: blk.split("\n")
        )
      end
    end

    superblocks << blocks

    context.instance_exec do
      
      superblocks.each_with_index do |superblock, superindex|

        noteblock = []

        row do
          col 12, lg: 8, md: 9 do
            superblock.each_with_index do |block, index|
              if block.type == :note
                noteblock << block
                next
              end
      
              if block.type == :header
                div class: :pagebreak do end if superindex != 0 || index != 0
                h2 "#{block.lines.join('').sub(/^\# */, '')}"
              elsif block.type == :paragraph
                p do
                  block.generate(self)
                end
              elsif block.type == :ul
                ul do
                  block.lines.each do |line|
                    li line.sub(/^- */, '')
                  end
                end
              elsif block.type == :table
                div class: "simpletable" do
                  table do
                    thead do
                      block.lines[1].split('|').compact.each do |x|
                        next if x.length == 0
                        th x
                      end
                    end
                    block.lines[2..-1].each do |line|
                      if line.start_with?('|')
                        tr do
                          line.split('|').compact.each do |x|
                            next if x.length == 0
                            td x
                          end
                        end
                      end
                    end
                  end
                end
              elsif block.type == :hr
                hr
              else
                div do
                  block.generate(self)
                end
              end

            end
      
          end

          col 12, lg: 3, md: 3 do
            noteblock.each_with_index do |block, index|
              blockquote block.lines[1..-1].join(' ')
            end
          end

        end


      end
    end
  end
end

def page(filename, path)
  nd = Nicedoc.new(File.read(filename))

  empty_page path, "My first weaver page" do
    request_css 'css/main.css'
    row do
      col 9 do
        h1 nd.yaml['title']
      end
    end

    nd.renderer.generate(self)
  end

  # empty_page path, "My first weaver page" do

  #   request_css 'css/main.css'
  
  #   row do
  #     col 9 do
  
  
  #       h2 "Chapter 1"
  
  #       h1 "Introduction"
  
        
  #       p class: :noindent do
  #         span 'P', class: :dropcap
  #         text "rogramming languages are notations for describing computations to people and to machines. The world as we know it depends on programming languages, because all the software running on all the computers was written in some programming language. But, before a program can be run, it must first be translated into a form in which it can be executed by a computer."
  #       end
  
  #       p "Qorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
  
  #       br
  #       h3 "1.1 Language Processors"
  
  #       p do
  #         text "Simply stated, a compiler is a program that can read a program in one language - the "
  #         i "source "
  #         text "language - and translate it into an equivalent program in another language - "
  #       end
  
  #       blockquote do
  
  #         h4 "Caveats"
  
  #         p "You should avoid creating new objects when you have no memory.", class: :noindent
  
  #       end
  
        
  #       hr
  
  
  #       h2 "Chapter 2"
  
  #       h1 "Strange Things"
  
  #       p class: :noindent do
  #         span 'L', class: :dropcap
  #         text "orem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
  #       end
  
  #       p "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
  
  #       p "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
  
  #       h2 "Another header"
  
  #       h3 "Content subheader"
  #       p "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
  
  #       pre <<~CODE
  #         preformatted content
  #         some code
  #         printf 'abc'
  
  #         +-----------+    +-------+
  #         | Component |--->| Thing |
  #         +-----------+    +-------+
  #               |
  #               |
  #               v
  #           +--------+
  #           | Gadget |
  #           +--------+
  #         figure 1.1
  
  
  #         +------------------+-----+
  #         | strange thing    | no  |
  #         +------------------+-----+
  #         | Ore              | 2   |
  #         | Plant            | 5   |
  #         | Bone             | 1   |
  #         +------------------+-----+
  #         table 1.2a
  
  #       CODE
  
  
  
  #       text "Some text"
  
  #       h2 "Another header"
  
  #       h3 "Content subheader"
  
  #       p "Some comment"
  
  #       h4 "Content subsubheader"
  
  #       p "Some comment"
  
  #       h5 "Content subsubsubheader"
  
  #       h6 "Content subsubsubsubheader"
  
  #       p "Some comment"
  
  
  #       pre <<~CODE
  #         preformatted content
  #         some code
  #         printf 'abc'
  
  #         the lazy fox jumps over the moon cow
  
  #         123456
  
  #         I am the world
  #       CODE
  
  #       div class: :blog do
  #         h1 "Blog title"
  
  #         h2 "Post title"
  
  #         p <<~BLOGPOST
  #           These are contents of a blogpost. Blogposts are written in preformatted form and do not have paragraph indents. They also use a lighter font than the preformatted one.
  #         BLOGPOST
  
  #         p <<~BLOGPOST
  #           The reason they are this way is to show their opinionated and highly casual form. This also facilitates their use as casual text documents where diagrams can be drawn using ASCII art.
  #         BLOGPOST
  
  #         p <<~CODE
  #           Content from a blog
  
  
  
  #           +------------------+-----+
  #           | strange thing    | no  |
  #           +------------------+-----+
  #           | Ore              | 2   |
  #           | Plant            | 5   |
  #           | Bone             | 1   |
  #           +------------------+-----+
  #           table 1.2a
  #         CODE
  
  #         p do
  #           text "This is one "
  #           i "particularly"
  #           text " interesting piece of art."
  #         end
  
  #         pre <<~CONTENT
  #           preformatted text still works, but has a border as usual.
  #         CONTENT
          
  #       end
  #     end
  #   end
  # end
end

def source_page(filename, path)
  empty_page path, "source of #{filename}" do
    request_css 'css/main.css'
    row do
      col 9 do
        pre File.read(filename)
      end
    end
  end
end

