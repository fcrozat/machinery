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

shared_examples "inspect changed managed files" do |base|
  describe "--scope=changed-managed-files" do
    it "extracts list of managed files" do
      measure("Inspect system") do
        @machinery.run_command(
          "#{machinery_command} inspect #{@subject_system.ip} " \
            "#{inspect_options if defined?(inspect_options)} " \
            "--scope=changed-managed-files --extract-files",
          as: machinery_config[:owner]
        )
      end

      actual_files_list = @machinery.run_command(
        "#{machinery_command} show #{@subject_system.ip} --scope=changed-managed-files",
        as: machinery_config[:owner], stdout: :capture
      )

      expected_files_list = File.read("spec/data/changed_managed_files/#{base}")

      expect(actual_files_list).to match_machinery_show_scope(expected_files_list)
    end

    it "extracts files from the system" do
      description_json = @machinery.run_command(
        "cat  #{machinery_config[:machinery_dir]}/#{@subject_system.ip}/manifest.json",
        as: machinery_config[:owner],
        stdout: :capture
      )
      description = create_test_description(json: description_json)
      actual_managed_files_list = nil

      measure("Gather information about extracted files") do
        actual_managed_files_list = @machinery.run_command(
          "cd #{machinery_config[:machinery_dir]}/#{@subject_system.ip}/changed_managed_files/; find",
          as: machinery_config[:owner],
          stdout: :capture
        ).
          split("\n").
          map { |file_name| file_name.sub(/^\./, "") } # Remove trailing dots returned by find
      end

      # directories are also extracted and to make sure to only list the actual
      # changed sub directory or file the parent directories are filtered
      actual_managed_files = actual_managed_files_list.reject { |element|
        actual_managed_files_list.grep(/^#{element}.+/).any? || element == "."
      }

      expected_managed_files = description.changed_managed_files.files.select(&:file?).map(&:name)
      expect(actual_managed_files).to match_array(expected_managed_files)

      # test file content
      actual_content = @machinery.run_command(
        "cat #{machinery_config[:machinery_dir]}/#{@subject_system.ip}/changed_managed_files/usr/share/info/sed.info.gz",
        as: machinery_config[:owner], stdout: :capture
      )
      expect(actual_content).to include("changed managed files test entry")
    end

    it "deals with quotes in changed links" do
      description_json = @machinery.run_command(
        "cat  #{machinery_config[:machinery_dir]}/#{@subject_system.ip}/manifest.json",
        as: machinery_config[:owner],
        stdout: :capture
      )
      description = create_test_description(json: description_json)
      expect(description["changed_managed_files"]["files"]).to include(
        ChangedManagedFile.new(
          name: "/opt/test-quote-char/link",
          package_name: "test-quote-char",
          package_version: "1.0",
          status: "changed",
          changes: ["link_path"],
          mode: "777",
          user: "root",
          group: "root",
          type: "link",
          target: "/opt/test-quote-char/target-with-quote'-foo"
        )
      )
    end
  end
end
