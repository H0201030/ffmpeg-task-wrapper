# Ffmpeg Wrapper

- Convert video format
- Merge audio + video to one file
- Rotate video
- Split video into segments
- Speedup/Slowdown videos
- Concatenate video segments to one video

# Example

```ruby
convert = Ffmpeg.new(:convert) do
  input "input.mov"
  output "output.mp4"
end

convert.execute
```

# License

Released under MIT Licence. By [Wang Zhuochun](https://github.com/zhuochun).
