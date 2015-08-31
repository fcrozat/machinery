# Copyright (c) 2013-2015 SUSE LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 3 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com
require "cheetah"
class DockerSystem < System
  attr_accessor :host

  def initialize(host)
    @host = host
    check_host
    check_if_container_is_running
  end

  def check_host
    all_container_ids = []
    running_docker_containers = Cheetah.run("docker", "ps", "-a", stdout: :capture)
    running_docker_containers.each_line do |container_id|
      all_container_ids << container_id.split(" ").first
    end
    all = all_container_ids.drop(1)
    if all.include?(@host) == false
        raise Machinery::Errors::InspectionFailed.new "Can not inspect container: Invaild Container ID"
    end
  end

  def check_if_container_is_running
    lines = []
    all_containers = Cheetah.run("docker", "ps", "-a", stdout: :capture)
    all_containers.each_line do |container|
      lines << container.split(" ")
      if container.start_with?(@host)
        if container.split(" ").include?("Exited")
           raise Machinery::Errors::InspectionFailed.new(
             "Container is not running currently. Start container before the" \
             " inspection by running:\n`docker start #{@host}`"
           )
         end
      end
    end
  end

  def requires_root?
    false
  end

  def run_command(*args)
    #debugger
    options = args.last.is_a?(Hash) ? args.pop : {}

    # There are three valid ways how to call Cheetah.run, whose interface this
    # method mimics. The following code ensures that the "commands" variable
    # consistently (in all three cases) contains an array of arrays specifying
    # commands and their arguments.
    #
    # See comment in Cheetah.build_commands for more detailed explanation:
    #
    #   https://github.com/openSUSE/cheetah/blob/0cd3f88c1210305e87dfc4852bb83040e82d783f/lib/cheetah.rb#L395
    #
    commands = args.all? { |a| a.is_a?(Array) } ? args : [args]

    # When ssh executes commands, it passes them through shell expansion. For
    # example, compare
    #
    #   $ echo '$HOME'
    #   $HOME
    #
    # with
    #
    #   $ ssh localhost echo '$HOME'
    #   /home/dmajda
    #
    # To mitigate that and maintain usual Cheetah semantics, we need to protect
    # the command and its arguments using another layer of escaping.
    escaped_commands = commands.map do |command|
      command.map { |c| Shellwords.escape(c) }
    end

    # Arrange the commands in a way that allows piped commands trough ssh.
    piped_args = escaped_commands[0..-2].flat_map do |command|
      [*command, "|"]
    end + escaped_commands.last

    if options[:disable_logging]
      cheetah_class = Cheetah
    else
      cheetah_class = LoggedCheetah
    end
    with_utf8_locale do
      cheetah_class.run(*["docker", "exec", "-i", host, "bash", "-c", piped_args.compact.flatten.join(" "), options])

    end
  end

  # Retrieves files specified in filelist from the local system and raises an
  # Machinery::Errors::RsyncFailed exception when it's not successful. Destination is
  # the directory where to put the files.
  def retrieve_files(filelist, destination)
    filelist.each do |file|
      destination_path = File.join(destination, file)

      FileUtils.mkdir_p(File.dirname(destination_path))
      output = File.open(destination_path, "w+")
      run_command("cat", file, stdout: output)
      LoggedCheetah.run("chmod", "og-rwx", destination_path)
    end
  end

  # Reads a file from the System. Returns nil if it does not exist.
  def read_file(file)
    run_command("cat", file, stdout: :capture)
  rescue Errno::ENOENT
    # File not found, return nil
    return
  end

  # Copies a file to the local system
  def inject_file(source, destination)
    FileUtils.copy(source, destination)
  rescue => e
    raise Machinery::Errors::InjectFileFailed.new(
      "Could not inject file '#{source}' to local system.\n" \
      "Error: #{e}"
    )
  end

  # Removes a file from the System
  def remove_file(file)
    run_command("rm", file)
  rescue => e
    raise Machinery::Errors::RemoveFileFailed.new(
      "Could not remove file '#{file}' from docker system'.\n" \
      "Error: #{e}"
    )
  end
end
