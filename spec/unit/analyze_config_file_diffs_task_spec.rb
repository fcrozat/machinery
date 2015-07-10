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

describe AnalyzeConfigFileDiffsTask do
  initialize_system_description_factory_store

  let(:store) { SystemDescriptionStore.new }
  let(:description) {
    description = create_test_description(json: <<-EOF, store_on_disk: true)
      {
        "repositories": [
          {
            "alias": "repo-debug",
            "name": "openSUSE-13.1-Debug",
            "type": null,
            "url": "http://download.opensuse.org/debug/distribution/13.1/repo/oss/",
            "enabled": true,
            "autorefresh": true,
            "gpgcheck": true,
            "priority": 98
          },
          {
            "alias": "dvd_entry_alias",
            "name": "dvd_entry",
            "type": "yast2",
            "url": "dvd:///?devices=/dev/disk/by-id/ata-Optiarc_DVD+_-RW_AD-7200S,/dev/sr0",
            "enabled": true,
            "autorefresh": false,
            "gpgcheck": true,
            "priority": 2
          }
        ], "config_files": {
          "extracted": true,
          "files": [
            {
              "name": "/etc/pam.d/login",
              "package_name": "login",
              "package_version": "3.41",
              "status": "changed",
              "changes": [
                "md5"
              ]
            },
            {
              "name": "/etc/modprobe.d/unsupported-modules",
              "package_name": "aaa_base",
              "package_version": "3.11.1",
              "status": "changed",
              "changes": [
                "md5"
              ]
            },
            {
              "name": "/etc/inittab",
              "package_name": "aaa_base",
              "package_version": "3.11.1",
              "status": "changed",
              "changes": [
                "md5"
              ]
            },
            {
              "name": "/etc/mode_changed_only",
              "package_name": "mode_changed_only",
              "package_version": "1",
              "status": "changed",
              "changes": [
                "mode"
              ]
            }
          ]
        },
        "os": {
          "name": "SUSE Linux Enterprise Server 11",
          "version": "11 SP3",
          "architecture": "x86_64"
        }
      }
    EOF
    FileUtils.mkdir_p(File.join(description.description_path, "config_files"))

    description
  }
  subject {
    AnalyzeConfigFileDiffsTask.new
  }

  let(:no_online_repo_description) {
    description = create_test_description(json: <<-EOF, store_on_disk: true)
      {
        "repositories": [
          {
            "alias": "repo-debug",
            "name": "openSUSE-13.1-Debug",
            "type": null,
            "url": "http://download.opensuse.org/debug/distribution/13.1/repo/oss/",
            "enabled": false,
            "autorefresh": true,
            "gpgcheck": true,
            "priority": 98
          },
          {
            "alias": "dvd_entry_alias",
            "name": "dvd_entry",
            "type": "yast2",
            "url": "dvd:///?devices=/dev/disk/by-id/ata-Optiarc_DVD+_-RW_AD-7200S,/dev/sr0",
            "enabled": true,
            "autorefresh": false,
            "gpgcheck": true,
            "priority": 2
          }
        ], "config_files": {
          "extracted": true
        },
        "os": {
          "name": "SUSE Linux Enterprise Server 11",
          "version": "11 SP3",
          "architecture": "x86_64"
        }
      }
    EOF
    FileUtils.mkdir_p(File.join(description.description_path, "config_files"))

    description
  }

  before(:each) do
    allow_any_instance_of(Zypper).to receive(:add_repo)
    allow_any_instance_of(Zypper).to receive(:remove_repo)
    allow_any_instance_of(Zypper).to receive(:refresh)
  end

  describe "#analyze" do
    silence_machinery_output
    before(:each) do
      allow(Zypper).to receive(:cleanup)
    end

    it "analyzes all files with changes" do
      expect_any_instance_of(Zypper).to receive(:download_package).
        with("aaa_base-3.11.1").and_return("/some/path/aaa_base")
      expect_any_instance_of(Zypper).to receive(:download_package).
        with("login-3.41").and_return("/some/path/login")
      expect(Rpm).to receive(:new).with("/some/path/aaa_base").
        and_return(double(diff: "some aaa_base diff")).twice
      expect(Rpm).to receive(:new).with("/some/path/login").
        and_return(double(diff: "some login diff"))

      subject.analyze(description)
      diff_count = Dir.glob(File.join(description.description_path, "/**/*.diff")).size
      expect(diff_count).to eq(3)
      example_content = File.read(
        File.join(description.description_path, "analyze/config_file_diffs/etc/pam.d/login.diff")
      )
      expect(example_content).to eq("some login diff")
    end

    it "skips packages which couldn't be downloaded" do
      expect_any_instance_of(Zypper).to receive(:download_package).
        with("aaa_base-3.11.1").and_return(nil)
      expect_any_instance_of(Zypper).to receive(:download_package).
        with("login-3.41").and_return("")
      expect(Machinery::Ui).to receive(:warn).twice
      expect(subject).to_not receive(:generate_diff)

      subject.analyze(description)
    end

    it "raises an error when the description is missing information" do
      task = AnalyzeConfigFileDiffsTask.new
      expect {
        task.analyze(SystemDescription.new("foo",
          SystemDescriptionMemoryStore.new))
      }.to raise_error(Machinery::Errors::SystemDescriptionError)
    end
  end

  describe "#inspection_list" do
    it "groups files by package" do
      expected_group = Package.new(
        "name"    => "aaa_base",
        "version" => "3.11.1",
        "files"   => ["/etc/modprobe.d/unsupported-modules", "/etc/inittab"]
      )

      expect(subject.send(:files_by_package, description)).to include(expected_group)
    end

    it "ignores files where the md5sum did not change" do
      match = subject.send(:files_by_package, description).find {
        |e| e["package_name"] == "mode_changed_only"
      }

      expect(match).to be_nil
    end

    it "raises error if no online repository is available" do
      expect { subject.analyze(no_online_repo_description) }.to raise_error(
        Machinery::Errors::AnalysisFailed
      )
    end
  end

  describe "#check_for_zypper_version" do
    it "raises an error if zypper version is outdated and OS is 13.1" do
      allow(Cheetah).to receive(:run).with(
        "zypper", "--version", stdout: :capture
      git ).and_return("zypper 1.8.12\n").at_least(:once)
      allow_any_instance_of(Zypper).to receive(:download_package)
      expect(LocalSystem).to receive(:os).and_return({"name" => "openSUSE 13.1 (Bottle)"})

      expect{ subject.check_for_zypper_version }.to raise_error(Machinery::Errors::AnalysisFailed)
      LocalSystem.class_variable_set("@@os", nil) # LocalSystem.os is cached
    end
  end
end
