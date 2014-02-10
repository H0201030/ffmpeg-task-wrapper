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
# ruby test.rb
#  - t:task, clean, convert, split, speed, concat, ios, web
#  - p:path/file
#  - s:timesteps
#
# this one is for iOS uploaded files
########################################

path    = "test1"
file    = "input.mov"
times   = [8.6, 13.2, 20.8, 27.3]
frame   = false
new_fps = 30

task = ["clean", "convert", "split", "speed", "concat"]

ARGV.each do |o|
  k, v = o.split(":")

  if k == 't'
    v = v.split(",")

    if v.include?("web")
      path  = "test2"
      file  = "input.mp4"
      times = [3.6, 8.2, 15, 21]
      frame = true

      task = v if v.size > 1
    else
      task = v
    end
  elsif k == 'p'
    path, file = v.split("/")
  elsif k == 's'
    times = v.split(",").map(&:to_f)
  end
end

puts "process #{path}/#{file} at timesteps #{times}"

# clean up directory
if task.include? "clean"
  puts "clean files"
  clean_file(path, "tmp_*")
end

########################################
# convert to i frames
########################################
if task.include? "convert"
  clean_file(path, "tmp_convert*")

  convert = Ffmpeg.new(:convert) do
    input expand("./#{path}/#{file}")
    output expand("./#{path}/tmp.mp4")
  end

  puts "convert = #{convert.execute}"

  exit unless convert.succeed?
end

########################################
# split
########################################
if task.include? "split"
  clean_file(path, "tmp_split_*")

  split = Ffmpeg.new(:split) do
    input expand("./#{path}/tmp_convert.mp4")
    output expand("./#{path}/tmp.mp4")
  end

  puts "split = #{split.execute(times)}"

  exit unless split.succeed?
end

########################################
# speed up/slow down
########################################
if task.include? "speed"
  clean_file(path, "tmp_*_speed*")

  speed  = Ffmpeg.new(:speed, no_audio: true, update_frames: frame, new_fps: new_fps)

  duration_diff = []
  times.inject(0) do |p, c|
    duration_diff << c.ceil - p
    c.ceil
  end

  puts "#{Dir[expand("./#{path}/tmp_split_*.mp4")].count} v.s. #{duration_diff}"

  Dir[expand("./#{path}/tmp_split_*.mp4")].each_with_index do |input, idx|
    speed.input = input
    speed.output = expand("./#{path}/tmp_#{idx}.mp4")

    to_speed = duration_diff[idx] / 2.0 # aim for 2s per split
    puts "speed [#{idx} -> #{to_speed}] = #{speed.execute(to_speed)}"
  end

  exit unless speed.succeed?
end

########################################
# concat
########################################
if task.include? "concat"
  clean_file(path, "tmp_concat*")

  concat = Ffmpeg.new(:concat, demuxer: true)
  concat.input(*Dir[expand("./#{path}/tmp_*_speed.mp4")])
  concat.output = expand("./#{path}/tmp.mp4")

  puts "#{concat.inputs}"
  puts "concat = #{concat.execute}"
end
