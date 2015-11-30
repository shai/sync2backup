require 'yaml'
require 'logger'
require 'mail'
require 'time'

# ruby C:\bin\sync2backup.rb

time = Time.new

Mail.defaults do
  delivery_method :smtp, address: "smtp.server.com", port: 25
end

logger = Logger.new(STDOUT)
logger.level = Logger::WARN

logger.debug("Created logger")
logger.info("Program started")
logger.warn("Nothing to do!")

dirs_list=YAML.load_file('C:\sync2backup.yml')

dirs_list['drive_list'].each do |key, hash|
  hash['src'].each do |src|
    begin
      logfile = "#{__FILE__}.#{src}.log.txt"
      logger = Logger.new(logfile, 'daily')
      cmd = "echo robocopy #{key}:\\#{src} \'->\' #{hash['dst']}\\#{src}"
      logger.debug cmd
      system (cmd)
      ec = $?.exitstatus
      if ec != 0
        puts 'exit status bad!'
        exit 1
      end
      logger.close
      mail = Mail.new do
        from 'example@example.com'
        to 'example@example.com'
        subject File.basename(__FILE__) + " of " + "#{key}:\\#{src} to #{hash['dst']}\\#{src} log " + time.strftime("%Y-%b-%d @ %H:%M")
        body File.read(logfile)
        add_file :filename => logfile, :content => File.read(logfile)
      end

      mail.deliver
    rescue Exception => e
      puts "bad command: #{cmd}"
      p e
      # p ec
      exit
    end
  end
end
