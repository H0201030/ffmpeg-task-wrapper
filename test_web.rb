require "./ffmpeg"

# helpers
def expand(path)
  File.expand_path(path, File.dirname(__FILE__))
end

def clean_file(path, file)
  files = File.join(expand(path), file)

  Dir[files].each do |f|
    File.delete(f)
  end
end

########################################
# command:
# ruby test.rb path file timesteps
#
# this one is for web uploaded files
########################################

path  = ARGV[0] || "test2"
file  = ARGV[1] || "input.mp4"
times = ARGV[2] ? ARGV[2].split(",").map(&:to_f) : [3.6, 8.2, 10]

puts "process #{path}/#{file} at timesteps #{times}"

# clean up directory
clean_file(path, "tmp_*")

# speed up to 20fps
speed = Ffmpeg.new(:speed, no_audio: true, update_frames: true) do
  input expand("./#{path}/#{file}")
  output expand("./#{path}/tmp.mp4")
end

puts "speed to 20fps = #{speed.execute(2.0)}"

exit unless speed.succeed?

# convert
convert = Ffmpeg.new(:convert) do
  input expand("./#{path}/tmp_speed.mp4")
  output expand("./#{path}/tmp.mp4")
end

puts "convert = #{convert.execute}"

# split
split = Ffmpeg.new(:split) do
  input expand("./#{path}/tmp_convert.mp4")
  output expand("./#{path}/tmp.mp4")
end

puts "split = #{split.execute(times)}"

exit unless split.succeed?

# speed up/slow down
speed  = Ffmpeg.new(:speed, no_audio: true)

duration_diff = []
times.inject(0) do |p, c|
  duration_diff << c.ceil - p
  c.ceil
end

puts "#{split.outputs.count} v.s. #{duration_diff}"

split.outputs.each_with_index do |input, idx|
  speed.input = input
  speed.output = expand("./#{path}/tmp_#{idx}.mpg")
  to_speed = duration_diff[idx] / 3.0 # aim for 3s per split

  puts "speed [#{idx} -> #{to_speed}] = #{speed.execute(to_speed)}"
end

exit unless speed.succeed?

# concat
concat = Ffmpeg.new(:concat)
concat.input(Dir[expand("./#{path}/tmp_*_speed.mpg")])
concat.output = expand("./#{path}/tmp.mpg")

puts "#{concat.inputs}"
puts "concat = #{concat.execute}"
