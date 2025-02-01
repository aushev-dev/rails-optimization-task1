require_relative 'task-1.rb'
require 'ruby-prof'

RubyProf.measure_mode = RubyProf::WALL_TIME

result = RubyProf.profile { work(file_name: '100000.txt', disable_gc: true, progress_bar: false) }

RubyProf::FlatPrinter.new(result).print(File.open("ruby_prof_reports/flat.txt", "w+"))
RubyProf::GraphHtmlPrinter.new(result).print(File.open("ruby_prof_reports/graph.html", "w+"))
RubyProf::CallStackPrinter.new(result).print(File.open('ruby_prof_reports/callstack.html', 'w+'))
RubyProf::CallTreePrinter.new(result).print(:path => "ruby_prof_reports", :profile => 'callgrind')
