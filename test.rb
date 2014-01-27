require "./ffmpeg"

path  = ARGV[0] || "test"
file  = ARGV[1] || "input.mov"
times = ARGV[2] ? ARGV[2].split(",").map(&:to_f) : [8.6, 13.2, 20.8, 27.3]

puts "#{path}/#{file} at #{times}"

def expand(path)
  File.expand_path(path, File.dirname(__FILE__))
end

split = Ffmpeg.new(:split, no_audio: true) do
  input expand("./#{path}/#{file}")
  output expand("./#{path}/tmp.mp4")
end

puts "split = #{split.execute(times)}"

speed = Ffmpeg.new(:speed, no_audio: true)
merge = Ffmpeg.new(:concat)

duration_diff = []
times.inject(0) do |p, c|
  duration_diff << c.ceil - p
  c.ceil
end

puts "#{split.outputs.count} v.s. #{duration_diff}"

split.outputs.each_with_index do |input, idx|
  speed.input = input
  speed.output = expand("./#{path}/tmp_#{idx}.mp4")
  to_speed = duration_diff[idx] / 3.0

  puts "speed [#{idx} -> #{to_speed}] = #{speed.execute(to_speed)}"

  merge.inputs << speed.outputs.last
end

merge.output = expand("./#{path}/final_output.mp4")

puts "#{merge.inputs}"
puts "#{merge.send(:build_merge_cmd)}"
puts "#{merge.send(:build_concat_cmd)}"

puts "merge = #{merge.execute}"
