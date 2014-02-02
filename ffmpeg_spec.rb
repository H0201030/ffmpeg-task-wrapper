gem "minitest"

require "minitest/autorun"
require "./ffmpeg"

describe Ffmpeg do

  it "should be able to initialized" do
    ffmpeg = Ffmpeg.new(:merge)
    ffmpeg.cmd.must_equal :merge
  end

  it "can accept a block assignment" do
    ffmpeg = Ffmpeg.new(:merge) do
      input "input.mp4"
      output "dest_path/output.mp4"
    end

    ffmpeg.cmd.must_equal :merge
    ffmpeg.inputs.must_equal ["input.mp4"]
    ffmpeg.dest_path.must_equal "dest_path"
    ffmpeg.dest_prefix.must_equal "output"
    ffmpeg.dest_ext.must_equal ".mp4"
    ffmpeg.dest_file.must_equal "dest_path/output_merge.mp4"
  end

  it "can accept a block assignment with separated output" do
    ffmpeg = Ffmpeg.new(:merge) do
      input "input.mp4"
      output "dest_path", ".mp4"
    end

    ffmpeg.cmd.must_equal :merge
    ffmpeg.inputs.must_equal ["input.mp4"]
    ffmpeg.dest_path.must_equal "dest_path"
    ffmpeg.dest_prefix.must_equal ""
    ffmpeg.dest_ext.must_equal ".mp4"
    ffmpeg.dest_file.must_equal "dest_path/_merge.mp4"
  end

  it "can accept assignments individually" do
    ffmpeg = Ffmpeg.new(:merge)
    ffmpeg.input = "input.mp4"
    ffmpeg.output = "dest_path/output.mp4"

    ffmpeg.cmd.must_equal :merge
    ffmpeg.inputs.must_equal ["input.mp4"]
    ffmpeg.dest_path.must_equal "dest_path"
    ffmpeg.dest_prefix.must_equal "output"
    ffmpeg.dest_ext.must_equal ".mp4"
  end

  it "should generate dest_file" do
    ffmpeg = Ffmpeg.new(:merge) do
      output "test/prefix.mp4"
    end

    ffmpeg.dest_file.must_equal "test/prefix_merge.mp4"
    ffmpeg.dest_file('_err').must_equal "test/prefix_merge_err.mp4"
    ffmpeg.dest_file('_err', ".log").must_equal "test/prefix_merge_err.log"
  end

  it "should build correct merge cmd" do
    ffmpeg = Ffmpeg.new(:merge) do
      input 'audio.wav', 'video.webm'
      output 'merged/output.mp4'
    end

    ffmpeg.send(:build_merge_cmd).must_equal 'ffmpeg'\
      ' -i "audio.wav" -i "video.webm" "merged/output_merge.mp4"'
    ffmpeg.outputs.must_equal ["merged/output_merge.mp4"]
  end

  it "should build correct concat cmd" do
    ffmpeg = Ffmpeg.new(:concat, no_mpeg: true) do
      input './tmp_*.wav'
      output 'merged/output.mp4'
    end

    ffmpeg.send(:build_concat_cmd).must_equal 'ffmpeg'\
      " -f concat -i <(printf \"file '%s'\\n\" ./tmp_*.wav)"\
      ' -c copy "merged/output_concat.mp4"'
    ffmpeg.outputs.must_equal ["merged/output_concat.mp4"]
  end

  it "should build correct concat mpeg cmd" do
    ffmpeg = Ffmpeg.new(:concat) do
      input './tmp_1.mpg', './tmp_2.mpg'
      output 'merged/output.mpg'
    end

    ffmpeg.send(:build_concat_cmd).must_equal 'ffmpeg'\
      ' -i "concat:./tmp_1.mpg|./tmp_2.mpg"'\
      ' -c copy "merged/output_concat.mpg"'
    ffmpeg.outputs.must_equal ["merged/output_concat.mpg"]
  end

  it "should format time" do
    ffmpeg = Ffmpeg.new(:merge)

    ffmpeg.send(:format_time,    0).must_equal "00:00:00"
    ffmpeg.send(:format_time,    9).must_equal "00:00:09"
    ffmpeg.send(:format_time,   19).must_equal "00:00:19"
    ffmpeg.send(:format_time,   60).must_equal "00:01:00"
    ffmpeg.send(:format_time,   61).must_equal "00:01:01"
    ffmpeg.send(:format_time,   71).must_equal "00:01:11"
    ffmpeg.send(:format_time,  619).must_equal "00:10:19"
    ffmpeg.send(:format_time,  661).must_equal "00:11:01"
    ffmpeg.send(:format_time, 3600).must_equal "01:00:00"
    ffmpeg.send(:format_time, 3661).must_equal "01:01:01"
  end

  it "should build correct split cmd" do
    ffmpeg = Ffmpeg.new(:split) do
      input "input.mp4"
      output "tmp/out.mp4"
    end

    ffmpeg.send(:build_split_cmd, [1.8, 2.6]).must_equal 'ffmpeg -i "input.mp4"'\
      ' -an -vcodec copy -ss 00:00:00 -t 00:00:02 "tmp/out_split_part0.mp4"'\
      ' -an -vcodec copy -ss 00:00:02 -t 00:00:01 "tmp/out_split_part1.mp4"'

    ffmpeg.send(:build_split_cmd, [1.8, 4.6, 10.6]).must_equal 'ffmpeg -i "input.mp4"'\
      ' -an -vcodec copy -ss 00:00:00 -t 00:00:02 "tmp/out_split_part0.mp4"'\
      ' -an -vcodec copy -ss 00:00:02 -t 00:00:03 "tmp/out_split_part1.mp4"'\
      ' -an -vcodec copy -ss 00:00:05 -t 00:00:06 "tmp/out_split_part2.mp4"'
  end

  it "should build correct speedup/slowdown cmd" do
    ffmpeg = Ffmpeg.new(:speed, fps: 20, update_frames: true) do
      input "input.mp4"
      output "tmp/out.mp4"
    end

    ffmpeg.send(:build_speed_cmd, 2.5).must_equal 'ffmpeg -i "input.mp4" -r 40'\
      ' -filter_complex "[0:v]setpts=0.5*PTS[v];[0:a]atempo=2.0[a]"'\
      ' -map "[v]" -map "[a]" "tmp/out_speed.mp4"'

    ffmpeg = Ffmpeg.new(:speed) do
      input "input.mp4"
      output "tmp/out.mp4"
    end

    ffmpeg.send(:build_speed_cmd, 2.0).must_equal 'ffmpeg -i "input.mp4" '\
      ' -filter_complex "[0:v]setpts=0.5*PTS[v];[0:a]atempo=2.0[a]"'\
      ' -map "[v]" -map "[a]" "tmp/out_speed.mp4"'

    ffmpeg.send(:build_speed_cmd, 1.0).must_be_nil

    ffmpeg.send(:build_speed_cmd, 0.5).must_equal 'ffmpeg -i "input.mp4" '\
      ' -filter_complex "[0:v]setpts=2.0*PTS[v];[0:a]atempo=0.5[a]"'\
      ' -map "[v]" -map "[a]" "tmp/out_speed.mp4"'

    ffmpeg.send(:build_speed_cmd, 0.0).must_equal 'ffmpeg -i "input.mp4" '\
      ' -filter_complex "[0:v]setpts=2.0*PTS[v];[0:a]atempo=0.5[a]"'\
      ' -map "[v]" -map "[a]" "tmp/out_speed.mp4"'
  end

  it "should build correct speedup/slowdown cmd without audio" do
    ffmpeg = Ffmpeg.new(:speed, fps: 20, no_audio: true, update_frames: true) do
      input "input.mp4"
      output "tmp/out.mp4"
    end

    ffmpeg.send(:build_speed_cmd, 2.5).must_equal 'ffmpeg -i "input.mp4" -r 40'\
      ' -filter_complex "[0:v]setpts=0.5*PTS[v]"'\
      ' -map "[v]" "tmp/out_speed.mp4"'
  end

end
