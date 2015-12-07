#!/usr/bin/env ruby

# By Shai Ben-Naphtali
# Version: 1.0.0.0
# A Ruby wrapper for Windows's Robocopy cli tool to copy file data.
# This tool will copy source directories to their destination as defined in the required YAML.

begin
  require File.join(File.dirname(__FILE__), '../lib/PrintOut.rb')

  require 'yaml'
  require 'mail'
  require 'time'
  require 'fileutils'

  class MyCrazyException < StandardError
    def initialize(msg='My default message')
      super
    end
  end

  lockfilename = '../data/' + File.basename(__FILE__) + '.lock'
  lockfile = File.open(lockfilename, File::RDWR|File::CREAT, 644)
  raise MyCrazyException, File.basename(__FILE__) + ' already running. exiting.' unless lockfile.flock(File::LOCK_EX|File::LOCK_NB)

  time = Time.new

  yaml = File.join(File.dirname(__FILE__), '../data/sync2backup.yml')
  raise MyCrazyException, 'missing the YAML file' unless File.exist?(yaml)

  conf=YAML.load_file(File.join(File.dirname(__FILE__), '../data/sync2backup.yml'))

  conf['drive_list'].each do |driveList| # array ; iterate over drive list
    driveList.each do |drive, srcNdst| # hash ; iterate over drives
      srcNdst[0]['src'].each do |srcDirectory| # array ; iterate over source directories
        srcDirectory.each do |src, value|
          if value
            arr = Array.new
            value[0]['excludeDir'].each do |x|
              arr.push x
            end
            arr = arr.join(' ') # create a string from the array
            @arr = arr.chomp('"').reverse.chomp('"').reverse # remove leading and tailing double quotes of the string to be used in the command
          else
            @arr = ''
          end
        end
        src_clean = srcDirectory.first[0].gsub(/[\/\\]/, '_') # we replace slashes/backslashes from path and replace with underscore to be used in the log filename
        initialize_log_file(src_clean, false)

        # make sure the destination directory exists
        unless File.directory?("#{srcNdst[1]['dst']}")
          FileUtils.mkpath("#{srcNdst[1]['dst']}") # could raise Errno::ENOENT if destination drive (not directory) doesn't exist
        end

        # make sure the source directory exists
        raise MyCrazyException, "source directory \"#{drive}:\\#{srcDirectory.first[0]}\" doesn't exist, oops!" unless File.directory?("#{drive}:\\#{srcDirectory.first[0]}")
        time_in_log = time.strftime('%Y%m%d-%H%M')
        robocopy_log = "#{srcNdst[1]['dst']}\\robocopy_#{src_clean}_" + time_in_log + '.log'
        cmd = "robocopy \"#{drive}:\\#{srcDirectory.first[0]}\" \"#{srcNdst[1]['dst']}\\#{srcDirectory.first[0]}\" "\
                "#{conf['robocopyExtraParam']} /XJ /MIR /LOG:\"#{robocopy_log}\" /XF ntuser.* "\
                "/TEE /NP /R:0 /W:2 /XD #{@arr}"
        print_out (cmd)
        system (cmd)

        $log_file.close # close log file before email

        mail = Mail.new do
          from conf['mail_from']
          to conf['mail_to']
          subject File.basename(__FILE__) + ' of ' + "#{drive}:\\#{srcDirectory.first[0]} to #{srcNdst[1]['dst']}\\#{srcDirectory.first[0]} log " + time_in_log
          body cmd
          add_file :filename => File.basename($log_file), :content => File.read($log_file.path)
          File.exist?(robocopy_log) || next
          add_file :filename => File.basename(robocopy_log), :content => File.read(robocopy_log)
          delivery_method :smtp, address: conf['smtp'], port: conf['smtp_port']
        end

        mail.deliver # deliver the email now
        File.delete(robocopy_log) if File.exists?(robocopy_log)
      end
    end
  end
rescue Errno::EPIPE # Could happen when sending output to pipe to programs like 'head' that stops the reading from pipe early.
  exit 1
rescue Errno::ENOENT
  print_out("the destination directory couldn't be created")
rescue MyCrazyException => e
  puts e
  exit 1
rescue StandardError => se
  if $log
    print_out('there was a problem. exiting.')
    print_out(se, level='error')
  else
    puts se
  end
  exit 1
rescue Interrupt # Ctrl-c (SIGINT) or SystemExit which derives from Exception and not from StandardError
  puts "\nSilence! I kill you!!!"
  exit
end

lockfile.close
File.delete(lockfilename) if File.exists?(lockfilename)
puts(File.basename(__FILE__) + ' finished.')
