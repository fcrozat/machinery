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

require_relative "spec_helper"

describe DockerSystem do
  let(:false_container_id) { "0a0a0a0a0a0a" }
  let(:valid_container_id) { "076f46c1bef1" }
  let(:false_container_name) { "bla/dummy" }
  let(:valid_container_name) { "opensuse/registry" }
  let(:container) { double(Docker::Container) }
  let(:test_system) { DockerSystem.new(valid_container_id) }

  before(:each) do
    allow(Docker::Image).to receive(:exist?).with(valid_container_id).and_return(true)
    allow(Docker::Image).to receive(:exist?).with(false_container_id).and_return(false)
    allow(Docker::Image).to receive(:exist?).with(valid_container_name).and_return(true)
    allow(Docker::Image).to receive(:exist?).with(false_container_name).and_return(false)

    allow(Docker::Container).to receive(:create).and_return(container)
  end

  describe "#initialize" do
    context "when image id is given" do
      it "raises an error if image id is not valid" do
        expect { DockerSystem.new(false_container_id) }.to raise_error(Machinery::Errors::InspectionFailed)
      end

      it "does not raise an error if image id is valid" do
        expect { DockerSystem.new(valid_container_id) }.not_to raise_error
      end
    end

    context "when image name is given" do
      it "does raise an error if image name is valid" do
        expect { DockerSystem.new(false_container_name) }.to raise_error(Machinery::Errors::InspectionFailed)
      end

      it "does not raise an error if image name is valid" do
        expect { DockerSystem.new(valid_container_name) }.not_to raise_error
      end
    end

    it "sets the status of the DockerSystem Class to created" do
      docker_system = DockerSystem.new(valid_container_name)
      expect(docker_system.container_status).to eq("created")
    end
  end

  describe "#start" do
    it "calls DockerContainer start" do
      expect(container).to receive(:start)
      test_system.start
    end

    it "sets the status of the DockerSystem Class to started" do
      expect(container).to receive(:start)
      test_system.start
      expect(test_system.container_status).to eq("started")
    end
  end

  describe "#stop" do
    it "calls DockerContainer stop" do
      expect(container).to receive(:stop)
      test_system.stop
    end

    it "sets the status of the DockerSystem Class to stopped" do
      expect(container).to receive(:stop)
      test_system.stop
      expect(test_system.container_status).to eq("stopped")
    end
  end

  describe "#kill" do
    it "calls DockerContainer kill" do
      expect(container).to receive(:kill)
      test_system.kill
    end

    it "sets the status of the DockerSystem Class to killed" do
      expect(container).to receive(:kill)
      test_system.kill
      expect(test_system.container_status).to eq("killed")
    end
  end

  describe "#run_command" do
    it "runs the command using DockerContainer exec" do
      expect(container).to receive(:exec).with(["bash -c python"])
      test_system.run_command("bash -c python")
    end

    it "loggs the called methods" do
    #  require 'byebug'
    #  byebug
    end
  end
end
=begin

      system = DockerSystem.new("076f46c1bef1")
      expect(LoggedCheetah).to receive(:run).with(
          "docker", "exec", "-i", "c311f5336878", "bash", "-c", "bash -c python",
          stdin: "my stdin", stdout: :capture
        )
      system.run_command("bash", "-c", "python", stdin: "my stdin", stdout: :capture)


=end







#  describe "#start_container_instance" do
#
#     it "starts an own container for inspection of the image name" do
#       expect(Cheetah).to receive(:run).with(
#           "docker", "run", "--name", "machinery_inspection","-t", "-i", "opensuse/mariadb",
#           stdout: :capture
#         ).not_to raise_error
#     end
#
#     it "starts an own container for inspection of the image id" do
#       expect(Cheetah).to receive(:run).with(
#           "docker", "run", "--name", "machinery_inspection","-t", "-i", "076f46c1bef1",
#           stdout: :capture
#         ).not_to raise_error
#     end
#
#     it "throws an error if there was a failure during container creation" do
#       expect(Cheetah).to receive(:run).with(
#           "docker", "run", "--name", "machinery_inspection","-t", "-i", "x",
#           stdout: :capture
#         ).to raise_error
#     end
#
#
#
#
#   expect(Cheetah).to receive(:run).with(
#       "docker", "run", "--name", "machinery_inspection","-t", "-i", "opensuse/mariadb",
#       stdout: :capture
#   ).
#
#
#
#   expect(Cheetah).to receive(:run).with(
#     "docker", "run", "--name", "machinery_inspection","-t", "-i", "076f46c1bef1",
#       stdout: :capture
#   ).
#
#
#
#
#       and_return(docker_images_output)
#
#   expect { DockerSystem.new("bla") }.to raise_error(Machinery::Errors::InspectionFailed)
#
#   docker_container_name = DockerSystem.new("opensuse/mariadb")
#
#   lines = []
#   running_containers = Cheetah.run("docker", "ps", "-a", stdout: :capture)
#     running_containers.each_line do |container|
#       lines << container.split(" ")
#     if container.start_with?(@container) && container.split(" ").include?("Exited")
#       raise Machinery::Errors::InspectionFailed.new(
#         "Container is not running currently. Start container before the" \
#         " inspection by running:\n`docker start #{@container}`"
#       )
#     end
#   end
# end
