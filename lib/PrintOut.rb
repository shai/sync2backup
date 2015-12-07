#!/usr/bin/env ruby

require 'date'
require 'logger'

# Print to $log
# $log must be initialized first with function initializeLogFile
def print_out(message, level='info')
  if level.eql?('debug')
    $log.debug(message)
  elsif level.eql?('error')
    $log.error(message)
  else
    $log.info(message)
  end

end

def initialize_log_file(src, debug)
  $flag = true
  # Open log file and make sure log will write to stdout as well
  date = Time.now.strftime('%d-%m-%Y')
  log_dir = File.join(File.dirname(__FILE__), '../../logs')

  unless File.exists?(log_dir)
    begin
      Dir.mkdir(log_dir)
    rescue => e
      puts "Couldn't create logs dir: #{e}"
    end
  end

  $log_file = File.open(log_dir+'/'+src+'_'+date+'.log', 'w')
  $log = Logger.new MultiIO.new(STDOUT, $log_file)
  $log.level = Logger::INFO unless debug
  $log.datetime_format = '%Y-%m-%d %H:%M:%S] [PID'
end

# MultiIO lets you treat multiple IOs as one. You can write to a log file and to stdout at the same time.
class MultiIO
  def initialize(*targets)
    @targets = targets
  end

  def write(*args)
    @targets.each { |t| t.write(*args) }
  end

  def close
    @targets.each(&:close)
  end
end
