class Ffmpeg

  FFMPEG = ENV['FFMPEG'] || 'ffmpeg'

  attr_accessor :cmd, :inputs, :outputs, :dest_path, :dest_prefix, :dest_ext, :options

  def initialize(cmd, options = {}, &block)
    @cmd = cmd
    @inputs = []
    @outputs = []
    @options = options

    @options[:fps] ||= 10

    instance_eval(&block) if block_given?
  end

  def input(*files)
    @inputs += files
    @outputs = []
  end

  def input=(file)
    @inputs = [file]
    @outputs = []
  end

  def output(file)
    @dest_path   = File.dirname(file)
    @dest_ext    = File.extname(file)
    @dest_prefix = File.basename(file, @dest_ext)
  end

  def output=(file)
    @dest_path   = File.dirname(file)
    @dest_ext    = File.extname(file)
    @dest_prefix = File.basename(file, @dest_ext)
  end

  def dest_file(postfix = nil, ext = @dest_ext)
    File.join(@dest_path, "#{@dest_prefix}_#{@cmd}#{postfix}#{ext}")
  end

  def execute(*args)
    cmds = send("build_#{@cmd}_cmd", *args)

    if comds.nil?
      return true;
    elsif cmds.respond_to? :each
      cmds.each { |cmd| system(cmd, err: dest_file("_err", ".log")) }
    else
      system(cmds, err: dest_file("_err", ".log"))
    end
  end

  private

  def input_files
    @inputs.map { |i| "-i \"#{i}\"" }.join(" ")
  end

  def build_merge_cmd
    outputs << dest_file
    "#{FFMPEG} #{input_files} \"#{outputs.last}\""
  end

  def build_concat_cmd
    outputs << dest_file
    "#{FFMPEG} -i \"concat:#{@inputs.join('|')}\" -c copy \"#{outputs.last}\""
  end

  def build_split_cmd(split_points)
    cmds = []
    option = "-an -vcodec copy"

    split_points.inject(0) do |prev, cur|
      duration = cur.ceil - prev
      outputs << dest_file("_part#{cmds.count}")
      cmds << "#{option} -ss #{format_time(prev)} -t #{format_time(duration)} \"#{outputs.last}\""
      cur.ceil
    end

    "#{FFMPEG} #{input_files} #{cmds.join(' ')}"
  end

  def build_speed_cmd(times)
    return nil if (0.9..1.1).include?(times)

    times = [0.5, [2.0, times].min].max # atempo should within 0.5 - 2

    audio_times = times.round(2)
    video_times = (1.0 / times).round(2)

    video_speed_opt = "[0:v]setpts=#{video_times}*PTS[v]"
    audio_speed_opt = "[0:a]atempo=#{audio_times}[a]"

    keep_frames = times > 1 ? "-r #{(@options[:fps] * times).to_i}" : ""

    outputs << dest_file

    if options[:no_audio]
      "#{FFMPEG} #{input_files} #{keep_frames} -filter_complex \"#{video_speed_opt}\""\
      " -map \"[v]\" \"#{outputs.last}\""
    else
      "#{FFMPEG} #{input_files} #{keep_frames} -filter_complex"\
      " \"#{video_speed_opt};#{audio_speed_opt}\""\
      " -map \"[v]\" -map \"[a]\" \"#{outputs.last}\""
    end
  end

  def format_time(time)
    hour = rjust_time_component(time / 3600)
    min  = rjust_time_component((time % 3600) / 60)
    sec  = rjust_time_component((time % 60))

    "#{hour}:#{min}:#{sec}"
  end

  def rjust_time_component(t)
    t.to_s.rjust(2, "0")
  end

end
