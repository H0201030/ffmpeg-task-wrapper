File.open("./times.txt") do |file|
  while line = file.gets
    `ruby ./test.rb #{line}`
  end
end
