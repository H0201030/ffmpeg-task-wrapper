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

  describe "#build_concat_cmd" do
    it "should build concat mpeg" do
      ffmpeg = Ffmpeg.new(:concat) do
        input './tmp_1.mpg', './tmp_2.mpg'
        output 'merged/output.mpg'
      end

      ffmpeg.send(:build_concat_cmd).must_equal 'ffmpeg'\
        ' -i "concat:./tmp_1.mpg|./tmp_2.mpg"'\
        ' -c copy "merged/output_concat.mpg"'
      ffmpeg.outputs.must_equal ["merged/output_concat.mpg"]
    end

    #it "should build concat demuxer" do
    #  ffmpeg = Ffmpeg.new(:concat, demuxer: true) do
    #    input './tmp_1.mp4', './tmp_2.mp4'
    #    output 'merged/output.mp4'
    #  end

    #  ffmpeg.send(:build_concat_cmd).must_equal 'ffmpeg -f concat'\
    #    ' -i "merged/output_concat_tcc.txt"'\
    #    ' -c copy "merged/output_concat.mp4"'
    #  ffmpeg.outputs.must_equal ["merged/output_concat.mp4"]
    #end
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

  describe "#build_rotate_cmd" do
    before :each do
      @ffmpeg = Ffmpeg.new(:rotate) do
        input "input.mp4"
        output "tmp/out.mp4"
      end
    end

    it "should default rotate 90' clockwise" do
      @ffmpeg.send(:build_rotate_cmd).must_equal 'ffmpeg -i "input.mp4"'\
        ' -vf "transpose=1" "tmp/out_rotate.mp4"'
    end

    it "should rotate 90' CounterClockwise" do
      @ffmpeg.options[:rotation] = :cclockwise90

      @ffmpeg.send(:build_rotate_cmd).must_equal 'ffmpeg -i "input.mp4"'\
        ' -vf "transpose=2" "tmp/out_rotate.mp4"'
    end
  end

  describe "#build_speed_cmd" do
    before :each do
      @ffmpeg = Ffmpeg.new(:speed) do
        input "input.mp4"
        output "tmp/out.mp4"
      end
    end

    it "should speedup with fps updated" do
      @ffmpeg.options[:fps] = 20
      @ffmpeg.options[:update_frames] = true

      @ffmpeg.send(:build_speed_cmd, 2.5).must_equal 'ffmpeg -i "input.mp4"'\
        ' -r 50.0 -filter_complex'\
        ' "[0:v]setpts=0.4*PTS[v];[0:a]atempo=2.0;atempo=1.25[a]"'\
        ' -map "[v]" -map "[a]" "tmp/out_speed.mp4"'
    end

    it "should speedup without audio" do
      @ffmpeg.options[:no_audio] = true

      @ffmpeg.send(:build_speed_cmd, 2.5).must_equal 'ffmpeg -i "input.mp4" '\
        ' -filter:v "setpts=0.4*PTS" "tmp/out_speed.mp4"'
    end

    it "should speedup by 5 times" do
      @ffmpeg.send(:build_speed_cmd, 5.0).must_equal 'ffmpeg -i "input.mp4" '\
        ' -filter_complex'\
        ' "[0:v]setpts=0.2*PTS[v];[0:a]atempo=2.0;atempo=2.0;atempo=1.25[a]"'\
        ' -map "[v]" -map "[a]" "tmp/out_speed.mp4"'
    end

    it "should speedup by 2 times" do
      @ffmpeg.send(:build_speed_cmd, 2.0).must_equal 'ffmpeg -i "input.mp4" '\
        ' -filter_complex "[0:v]setpts=0.5*PTS[v];[0:a]atempo=2.0[a]"'\
        ' -map "[v]" -map "[a]" "tmp/out_speed.mp4"'
    end

    it "should speedup by 1 times" do
      @ffmpeg.send(:build_speed_cmd, 1.0).must_equal 'ffmpeg -i "input.mp4" '\
        ' -filter_complex "[0:v]setpts=1.0*PTS[v];[0:a]atempo=1.0[a]"'\
        ' -map "[v]" -map "[a]" "tmp/out_speed.mp4"'
    end

    it "should slowdown by 2 times" do
      @ffmpeg.send(:build_speed_cmd, 0.5).must_equal 'ffmpeg -i "input.mp4" '\
        ' -filter_complex "[0:v]setpts=2.0*PTS[v];[0:a]atempo=0.5[a]"'\
        ' -map "[v]" -map "[a]" "tmp/out_speed.mp4"'
    end

    it "should slowdown by 5 times" do
      @ffmpeg.send(:build_speed_cmd, 0.2).must_equal 'ffmpeg -i "input.mp4" '\
        ' -filter_complex'\
        ' "[0:v]setpts=5.0*PTS[v];[0:a]atempo=0.5;atempo=0.5;atempo=0.8[a]"'\
        ' -map "[v]" -map "[a]" "tmp/out_speed.mp4"'
    end
  end

end
