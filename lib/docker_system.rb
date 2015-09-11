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
require "docker"

class DockerSystem < System
  attr_reader :container_status

  def initialize(image)
    @image = image
    image_exist?
    create_container_from_image
  end

  def start
    @container.start
    @container_status = "started"
  end

  def stop
    @container.stop
    @container_status = "stopped"
  end

  def kill
    @container.kill
    @container_status = "killed"
  end

  def run_command(*args)
    @container.exec(args)
  end

  def requires_root?
    false
  end

  private
  def image_exist?
    if !Docker::Image.exist?(@image)
      raise Machinery::Errors::InspectionFailed.new(
          "Can not inspect container: Invaild Image NAME or ID"
        )
    end
  end

  def create_container_from_image
    @container = Docker::Container.create("Image" => "#{@image}")
    @container_status = "created"
  end
end


=begin



  def run_command(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}

    commands = args.all? { |a| a.is_a?(Array) } ? args : [args]

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
      cheetah_class.run(
        *["docker", "exec", "-i", container, "bash", "-c",
          piped_args.compact.flatten.join(" "), options]
      )
    end
  end

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
=end
