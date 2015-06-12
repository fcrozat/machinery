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

describe KiwiConfig do
  initialize_system_description_factory_store

  let(:name) { "name" }
  let(:store) { system_description_factory_store }
  let(:export_dir) { given_directory }
  let(:system_description_with_content) {
    create_test_description(
      scopes: ["os", "packages", "repositories", "patterns", "users_with_passwords", "groups"],
      name: name,
      store: store
    )
  }

  let(:system_description_with_sysvinit_services) {
    create_test_description(
      scopes: ["os_sles11", "packages", "repositories", "services_sysvinit"],
      name: name,
      store: store
    )
  }

  let(:system_description_with_systemd_services) {
    create_test_description(
      scopes: ["os_sles12", "packages", "repositories", "services"], name: name, store: store
    )
  }

  let(:system_description_with_modified_files) {
    create_test_description(
      scopes: ["os", "packages", "repositories", "services"],
      extracted_scopes: ["config_files", "unmanaged_files", "changed_managed_files"],
      name: name,
      store: store,
      store_on_disk: true
    )
  }

  describe "#initialize" do
    it "raises exception when OS is not supported for building" do
      class OsOpenSuse99_1 < Os
        def self.canonical_name
          "openSUSE 99.1 (Repetition)"
        end

        def self.can_run_machinery?
          false
        end
      end

      allow_any_instance_of(SystemDescription).to receive(:os).
        and_return(OsOpenSuse99_1.new)
      system_description_with_content.os.name = "openSUSE 99.1 (Repetition)"
      expect {
        KiwiConfig.new(system_description_with_content)
      }.to raise_error(
         Machinery::Errors::ExportFailed,
         /openSUSE 99.1/
      )
    end

    it "applies the packages to the kiwi config" do
      config = KiwiConfig.new(system_description_with_content)

      users = config.xml.xpath("/image/users/user")
      expect(users.count).to eq(1)
      expect(users[0].attr("home")).to eq("/root")
      packages = config.xml.xpath("/image/packages/package")
      expect(packages.count).to eq(1)
      expect(packages[0].attr("name")).to eq("bash")
    end

    it "applies the packages to the kiwi config" do
      config = KiwiConfig.new(system_description_with_content)

      packages = config.xml.xpath("/image/packages/package").
        map { |e| e.attr("name") }
      expect(packages).not_to include("openSUSE-release-dvd")
    end

    it "applies the patterns to the kiwi config" do
      config = KiwiConfig.new(system_description_with_content)
      patterns = config.xml.xpath("/image/packages/namedCollection")

      expect(patterns.count).to eq(1)
      expect(patterns[0].attr("name")).to eq("base")
    end

    it "applies the repositories to the kiwi config" do
      config = KiwiConfig.new(system_description_with_content)

      repositories = config.xml.xpath("/image/repository")

      # enabled web based repositories go to config.xml if they have a type
      expect(repositories.count).to eq(3)
      expect(repositories[0].attr("type")).to eq("rpm-md")
      expect(repositories[0].children[0].attr("path")).to \
        eq("http://download.opensuse.org/repositories/devel:/languages:/nodejs/openSUSE_13.1/")
      expect(repositories[0].attr("priority")).to eq("1")

      # all repositories go to config.sh
      expect(config.sh.scan(/zypper -n ar/).count).to eq(7)
      expect(config.sh.scan(/zypper -n mr/).count).to eq(7)

      expect(config.sh).to include("zypper -n ar --name='nodejs' --type='rpm-md' 'http://download.opensuse.org/repositories/devel:/languages:/nodejs/openSUSE_13.1/' 'nodejs_alias'\n")
      expect(config.sh).to include("zypper -n mr --priority=1 'nodejs'\n")
      expect(config.sh).to include("zypper -n ar --name='openSUSE-13.1-1.7' --type='yast2' --disable 'cd:///?devices=/dev/disk/by-id/ata-Optiarc_DVD+_-RW_AD-7200S,/dev/sr0' 'openSUSE-13.1-1.7_alias'\n")
      expect(config.sh).to include("zypper -n mr --priority=2 'openSUSE-13.1-1.7'\n")

      # repositories without a type have no "--type" option
      expect(config.sh).to include("zypper -n ar --name='repo_without_type' 'http://repo-without-type' 'repo_without_type_alias'\n")

      # disabled repositories have a "--disabled" option
      expect(config.sh).to include("zypper -n ar --name='disabled_repo' --disable 'http://disabled-repo' 'disabled_repo_alias'\n")

      # autorefreshed repositories have a "--refresh" option
      expect(config.sh).to include("zypper -n ar --name='autorefresh_enabled' --refresh 'http://autorefreshed-repo' 'autorefresh_enabled_alias'\n")

      # NCC repositories are not added to the system, just used for building
      expect(config.sh).not_to include("https://nu.novell.com/")
    end

    it "raises an error if no repository is activated" do
      description = system_description_with_content
      description["repositories"].each do |repository|
        repository.enabled = false
      end
      expect { KiwiConfig.new(description) }.to raise_error(
        Machinery::Errors::MissingRequirement,
        /The system description doesn't contain any enabled or network reachable repository/
      )
    end
    it "raises an error if no repository is activated" do
      description = system_description_with_content
      description["repositories"].each do |repository|
        repository.enabled = false
      end
      expect { KiwiConfig.new(description) }.to raise_error(
        Machinery::Errors::MissingRequirement,
        /The system description doesn't contain any enabled or network reachable repository/
      )
    end

    it "raises an error if no repository is reachable via network" do
      description = system_description_with_content
      description["repositories"].each do |repository|
        repository.url = "cd:///?devices=/dev/disk/by-id/ata-Optiarc_DVD+_-RW_AD-7200S,/dev/sr0"
      end
      expect { KiwiConfig.new(description) }.to raise_error(
        Machinery::Errors::MissingRequirement,
        /The system description doesn't contain any enabled or network reachable repository/
      )
    end

    it "escapes the repository aliases in the config.xml file" do
      config = KiwiConfig.new(
        create_test_description(
          scopes: ["os", "packages", "repositories"], name: name, store: store
        )
      )
      repositories = config.xml.xpath("/image/repository")

      # escapes the alias in the xml
      expect(repositories.last.attr("alias")).to eq("Alias-With-Spaces")

      # doesn't escape the alias in the config.sh
      expect(config.sh).to include("Alias With Spaces")
    end

    it "applies sysvinit services to kiwi config" do
      config = KiwiConfig.new(system_description_with_sysvinit_services)

      expect(config.sh).to include("chkconfig sshd on\n")
      expect(config.sh).to include("chkconfig rsyncd off\n")
    end

    it "writes a proper description" do
      config = KiwiConfig.new(system_description_with_sysvinit_services)

      author = config.xml.xpath("/image/description/author").children.text
      contact = config.xml.xpath("/image/description/contact").children.text
      specification = config.xml.xpath("/image/description/specification").children.text

      expect(author).to eq("Machinery")
      expect(contact).to eq("")
      expect(specification).to eq("Description of system 'name' exported by Machinery")
    end

    it "applies systemd services to kiwi config" do
      config = KiwiConfig.new(system_description_with_systemd_services)

      expect(config.sh).to include("systemctl enable sshd.service")
      expect(config.sh).to include("systemctl disable rsyncd.service")
      expect(config.sh).to include("systemctl mask crypto.service")

      # static, linked and *runtime states should be ignored
      expect(config.sh).not_to match(/systemctl static /)
      expect(config.sh).not_to match(/systemctl linked /)
      expect(config.sh).not_to match(/systemctl \w+-runtime /)
    end

    it "raises an error if the systemd service state is unknown" do
      system_description_with_systemd_services.services.services.first["state"] = "not_known"
      expect {
        KiwiConfig.new(system_description_with_systemd_services)
      }.to raise_error(Machinery::Errors::ExportFailed, /not_known/)
    end

    it "sets the target distribution and bootloader for openSUSE 13.1" do
      expect(system_description_with_content.os.name).to include("openSUSE 13.1")
      config = KiwiConfig.new(system_description_with_content)
      type_node = config.xml.xpath("/image/preferences/type")[0]

      expect(type_node["boot"]).to eq("vmxboot/suse-13.1")
      expect(type_node["bootloader"]).to eq("grub2")
    end

    it "handles quotes in changed links" do
      system_description_with_modified_files["changed_managed_files"]["files"] <<
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
      config = KiwiConfig.new(system_description_with_modified_files)
      config.write(export_dir)
      expect(config.sh).to include(
        "ln -s '/opt/test-quote-char/target-with-quote\\'-foo' '/opt/test-quote-char/link'"
      )
    end

    it "sets the target distribution and bootloader for SLES12" do
      config = KiwiConfig.new(
        create_test_description(
          scopes: ["os_sles12", "packages", "repositories"], name: name, store: store
        )
      )
      type_node = config.xml.xpath("/image/preferences/type")[0]

      expect(type_node["boot"]).to eq("vmxboot/suse-SLES12")
      expect(type_node["bootloader"]).to eq("grub2")
    end

    it "sets the image format to qcow2" do
      config = KiwiConfig.new(system_description_with_content)
      type_node = config.xml.xpath("/image/preferences/type")[0]

      expect(type_node["format"]).to eq("qcow2")
    end

    it "throws an error if changed config files are part of the system description but don't exist on the filesystem" do
      scope = "config_files"
      system_description_with_modified_files.scope_file_store(scope).remove
      expect {
        KiwiConfig.new(system_description_with_modified_files)
      }.to raise_error(Machinery::Errors::SystemDescriptionError,
        /#{Machinery::Ui.internal_scope_list_to_string(scope)}/)
    end

    it "throws an error if changed managed files are part of the system description but don't exist on the filesystem" do
      scope = "changed_managed_files"
      system_description_with_modified_files.scope_file_store(scope).remove
      expect {
        KiwiConfig.new(system_description_with_modified_files)
      }.to raise_error(Machinery::Errors::SystemDescriptionError,
        /#{Machinery::Ui.internal_scope_list_to_string(scope)}/)
    end

    it "throws an error if unmanaged files are part of the system description but don't exist on the filesystem" do
      scope = "unmanaged_files"
      system_description_with_modified_files.scope_file_store(scope).remove
      expect {
        KiwiConfig.new(system_description_with_modified_files)
      }.to raise_error(Machinery::Errors::SystemDescriptionError,
        /#{Machinery::Ui.internal_scope_list_to_string(scope)}/)
    end

    it "applies 'pre-process' config" do
      config = KiwiConfig.new(
        system_description_with_content,
        enable_ssh: true
      )
      expect(config.sh).to include("suseInsertService sshd")
    end
  end

  describe "#write" do
    it "writes the config to the specified file" do
      config = KiwiConfig.new(system_description_with_content)

      expect(File).to receive(:write).
        with(File.join(export_dir, "config.xml"),
          /<package name="bash"\/>/
        )
      expect(File).to receive(:write).
        with(File.join(export_dir, "config.sh"),
          /zypper -n ar.*repo_without_type/
        )
      allow(File).to receive(:write)

      config.write(export_dir)
    end

    it "applies 'pre-process' config" do
      config = KiwiConfig.new(
          system_description_with_content,
          enable_ssh: true
      )
      config.write(given_directory)

      expect(config.sh).to include("suseInsertService sshd")
    end

    it "applies 'post-process' config" do
      config = KiwiConfig.new(
          system_description_with_content,
          enable_dhcp: true
      )

      expect(config).to receive(:enable_dhcp)
      config.write(export_dir)
    end

    it "enables dhcp on SLES11 with the enable_dhcp option" do
      allow($stdout).to receive(:puts)
      network_config = File.join(export_dir, "/root/etc/sysconfig/network/ifcfg-eth0")

      config = KiwiConfig.new(
          system_description_with_sysvinit_services,
          enable_dhcp: true
      )
      config.write(export_dir)

      expect(
        File.exists?(File.join(export_dir, "/root/etc/udev/rules.d/70-persistent-net.rules"))
      ).to be(false)
      expect(File.exists?(network_config)).to be(true)

      expect(File.read(network_config)).to include("BOOTPROTO='dhcp'")
    end

    it "enables dhcp on SLES12 with the enable_dhcp option" do
      allow($stdout).to receive(:puts)
      network_config = File.join(export_dir, "/root/etc/sysconfig/network/ifcfg-lan0")
      system_description_with_content.os.name = "SUSE Linux Enterprise Server 12"

      config = KiwiConfig.new(
          system_description_with_content,
          enable_dhcp: true
      )
      config.write(export_dir)

      expect(
        File.exists?(File.join(export_dir, "/root/etc/udev/rules.d/70-persistent-net.rules"))
      ).to be(true)
      expect(File.exists?(network_config)).to be(true)

      expect(File.read(network_config)).to include("BOOTPROTO='dhcp'")
    end


    it "uses the name of the description as image name" do
      config = KiwiConfig.new(system_description_with_content)

      expect(File).to receive(:write).
        with(File.join(export_dir, "config.xml"),
          /<image .* name="#{system_description_with_content.name}"/
        )
      allow(File).to receive(:write)

      config.write(export_dir)
    end

    it "adds a readme to the kiwi export" do
      allow($stdout).to receive(:puts)

      readme = File.join(export_dir, "README.md")
      config = KiwiConfig.new(
          system_description_with_content
      )
      config.write(export_dir)

      expect(File.exists?(readme)).to be(true)

      expect(File.read(readme)).to include(
        "README for Kiwi export from Machinery"
      )
    end

    describe "with extracted files" do
      let(:config) { KiwiConfig.new(system_description_with_modified_files) }
      let(:manifest_path) { store.description_path(name) }

      it "restores the extracted config-files" do
        config.write(export_dir)

        expect(config.sh).to include("chmod 644 '/etc/cron tab'\n")
        expect(config.sh).to include("chown root:root '/etc/cron tab'\n")

        expect(config.sh).to include("rm -rf '/etc/deleted config'\n")

        expect(config.sh).to include("chmod 755 '/etc/somedir'\n")
        expect(config.sh).to include("chown user:group '/etc/somedir'\n")

        expect(config.sh).to include("rm -rf '/etc/replaced_by_link'\n")
        expect(config.sh).to include("ln -s '/tmp/foo' '/etc/replaced_by_link'\n")
        expect(config.sh).to include("chown --no-dereference root:target '/etc/replaced_by_link'\n")
      end

      it "copies the changed config files to the template root directory" do
        config_file = "/etc/cron tab"
        config.write(export_dir)

        # expect config file attributes to be set via config.sh
        expect(config.sh).to include("chmod 644 '#{config_file}'\n")
        expect(config.sh).to include("chown root:root '#{config_file}'\n")
        # expect config files to be stored in the template root directory
        expect(File.exists?(File.join(export_dir, "root", config_file))).to be(true)
      end

      it "copies the changed managed files to the template root directory" do
        changed_managed_file = "/etc/cron.daily/cleanup"
        config.write(export_dir)

        # expect changed-managed file attributes to be set via config.sh
        expect(config.sh).to include("chmod 644 '#{changed_managed_file}'\n")
        expect(config.sh).to include("chown user:group '#{changed_managed_file}'\n")

        # expect config files to be stored in the template root directory
        expect(File.exists?(File.join(export_dir, "root", changed_managed_file))).to be(true)
      end

      it "copies the unmanaged files tarballs into the root directory" do
        config.write(export_dir)

        expect(
          File.exists?(File.join(export_dir, "/root/tmp/unmanaged_files/files.tgz"))
        ).to be(true)
        expect(
          File.exists?(
            File.join(export_dir, "/root/tmp/unmanaged_files/trees/etc/tarball with spaces.tgz")
          )
        ).to be(true)

        expect(config.sh).to match(/find \/tmp\/unmanaged_files.*tar/)

        # expect filter to be present
        expect(
          File.exists?(File.join(export_dir, "/root/tmp/unmanaged_files_kiwi_excludes"))
        ).to be(true)
        expect(config.sh).to match(/tar.*-X '\/tmp\/unmanaged_files_kiwi_excludes' /)
      end

      it "deletes deleted config and changed managed files" do
        config.write(export_dir)

        expect(config.sh).to include("rm -rf '/etc/deleted config'")
        expect(config.sh).to include("rm -rf '/etc/deleted changed managed'")
      end

      it "sets up links" do
        config.write(export_dir)

        expect(config.sh).to include("rm -rf '/usr/bin/replaced_by_link'")
        expect(config.sh).to include("ln -s '/tmp/foo' '/usr/bin/replaced_by_link'")
        expect(config.sh).to include("chown --no-dereference root:target '/usr/bin/replaced_by_link'")
      end

      it "sets up directories" do
        config.write(export_dir)

        expect(config.sh).to include("chmod 644 '/etc/cron.d'")
        expect(config.sh).to include("chown user:group '/etc/cron.d'")
      end
    end

    it "generates a script for merging the users and groups" do
      config = KiwiConfig.new(system_description_with_content)

      config.write(export_dir)

      script_path = File.join(export_dir, "root", "tmp", "merge_users_and_groups.pl")

      expect(config.sh).to include("perl /tmp/merge_users_and_groups.pl /etc/passwd /etc/shadow /etc/group")
      expect(File.exists?(script_path)).to be(true)

      script = File.read(script_path)
      expect(script).to include("['root:x:0:0:root:/root:/bin/bash', 'root:$6$E4YLEez0s3MP$YkWtqN9J8uxEsYgv4WKDLRKxM2aNCSJajXlffV4XGlALrHzfHg1XRVxMht9XBQURDMY8J7dNVEpMaogqXIkL0.:16357::::::']")
      expect(script).to include("['vagrant:x:1000:100::/home/vagrant:/bin/bash', 'vagrant:$6$6V/YKqrsHpkC$nSAsvrbcVE8kTI9D3Z7ubc1L/dBHXj47BlL5usy0JNINzXFDl3YXqF5QYjZLTo99BopLC5bdHYUvkUSBRC3a3/:16373:0:99999:7:30:1234:']")
      expect(script).to include("'audio:x:17:tux,foo'")
    end

    it "calls kiwi helpers" do
      config = KiwiConfig.new(system_description_with_content)
      config.write(given_directory)

      [
        "baseMount",
        "suseConfig",
        "suseSetupProduct",
        "suseImportBuildKey",
        "baseCleanMount"
      ].each do |helper|
        expect(config.sh).to include(helper)
      end
    end
  end

  describe "#export_name" do
    it "returns the export name" do
      kiwi = KiwiConfig.new(system_description_with_content)

      expect(kiwi.export_name).to eq("name-kiwi")
    end
  end
end
