require "./ffmpeg"

# Public: steplize video to same speed
#
# Examples
#
#   input = File.expand_path("test1/input.MOV")
#   steplizer = VideoSteplizer.new input, "output.mp4", [8.6, 10.9, 13.2, 20.8, 27.3]
#   steplizer.execute
#
class VideoSteplizer

  attr_accessor :path, :input, :steps, :update_fps, :new_fps
  attr_reader :succeed, :output

  def initialize(input, output, steps, options = {})
    @path = File.dirname(input)
    @input = input
    @output = filepath(output)
    @steps = steps
    @update_fps = options[:update_frames] || false
    @new_fps = options[:new_fps] || 30
    @step_targets = options[:step_targets] || [2, 2, 5, 2, 5]
  end

  def execute
    @succeed = verify_steps && convert_video && split_video &&
      adjust_video_speed && concat_videos && cleanup_path
  end

  def succeed?
    @succeed
  end

  def cleanup_path
    cleanup("tmp_*")
    cleanup("*concat*.{txt,log}")
  end

  def verify_steps
    duration = Ffmpeg.length(@input)

    if @steps.size != @step_targets.size
      false
    elsif @steps[-2] >= duration
      false
    elsif @steps[-1] >= duration
      @steps[-1] = duration
      true
    else
      true
    end
  end

  def convert_video
    convert = Ffmpeg.new(:convert)
    convert.input = @input
    convert.output = filepath("tmp.mp4")

    convert.execute
  end

  def split_video
    split = Ffmpeg.new(:split)
    split.input = filepath("tmp_convert.mp4")
    split.output = filepath("tmp.mp4")

    split.execute(@steps)
  end

  def adjust_video_speed
    speed = Ffmpeg.new :speed,
      no_audio: true, update_frames: @update_fps, new_fps: @new_fps

    duration_diff = []
    # calculate step durations
    @steps.inject(0) do |p, c|
      duration_diff << c.ceil - p.to_f
      c.ceil
    end

    Dir[filepath("tmp_split_*.mp4")].each_with_index do |input, idx|
      speed.input = input
      speed.output = filepath("tmp_#{idx}.mp4")

      to_speed = duration_diff[idx] / @step_targets[idx]
      speed.execute(to_speed)
    end

    speed.succeed?
  end

  def concat_videos
    concat = Ffmpeg.new(:concat, demuxer: true)
    concat.input = *Dir[filepath("tmp_*_speed.mp4")]
    concat.output = @output

    concat.execute
  end

  private

  def filepath(name)
    File.join(@path, name)
  end

  def cleanup(pattern)
    file_pattern = File.join(@path, pattern)

    Dir[file_pattern].each do |file|
      File.delete(file)
    end
  end
end
