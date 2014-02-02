# Ffmpeg Wrapper

- Convert video format
- Merge audio + video to one file
- Split video into segments
- Speedup/Slowdown videos
- Concatenate videos (`mpg`) to one file

# Example

```ruby
convert = Ffmpeg.new(:convert) do
  input "input.mov"
  output "output.mp4"
end

convert.execute
```
