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

class Os < Machinery::Object
  include Machinery::Scope

  def self.scope_name
    "os"
  end

  def self.descendants
    @descendants ||= ObjectSpace.each_object(::Class).select do |klass|
      klass < self && klass.descendants.empty?
    end
  end

  def self.for(os_name)
    descendants.each do |os_class|
      if os_name == os_class.canonical_name
        os = os_class.new
        os.name = os_name
        return os
      end
    end
    os = OsUnknown.new
    os.name = os_name
    os
  end

  def self.from_json(json)
    scope_object = self.for(json["name"])
    scope_object.set_attributes(json)
    scope_object
  end

  def scope_name
    "os"
  end

  def self.buildable_systems
    []
  end

  def self.module_dependencies
    {}
  end

  def self.can_run_machinery?
    true
  end

  def self.supported_host_systems
    descendants.select { |os| os.can_run_machinery? }
  end

  def can_run_machinery?
    self.class.can_run_machinery?
  end

  def can_build?(os)
    self.class.buildable_systems.include?(os.class) && os.architecture == "x86_64"
  end

  def can_be_analyzed?
    false
  end

  def can_be_exported?
    false
  end

  def module_required_by_package(package)
    self.class.module_dependencies[package]
  end

  def canonical_name
    self.class.canonical_name
  end

  def display_name
    "#{name} #{version} (#{architecture})"
  end
end

class OsUnknown < Os
  def self.canonical_name
    "Unknown OS"
  end

  def self.can_run_machinery?
    false
  end
end

class OsSuse < Os
  def can_be_analyzed?
    true
  end

  def can_be_exported?
    true
  end
end

class OsSles11 < OsSuse
  def self.canonical_name
    "SUSE Linux Enterprise Server 11"
  end

  def self.can_run_machinery?
    false
  end

  def display_name
    version =~ /11 (.*)/
    sp = $1
    "#{name} #{sp} (#{architecture})"
  end
end

class OsSled12 < OsSuse
  def self.canonical_name
    "SUSE Linux Enterprise Desktop 12"
  end

  def self.buildable_systems
    [OsSled12]
  end

  def display_name
    "#{name} (#{architecture})"
  end
end

class OsSles12 < OsSuse
  def self.canonical_name
    "SUSE Linux Enterprise Server 12"
  end

  def self.buildable_systems
    [OsSles12]
  end

  def self.module_dependencies
    { "python-glanceclient" => "Public Cloud Module" }
  end

  def display_name
    "#{name} (#{architecture})"
  end
end

class OsOpenSuse < OsSuse
  def display_name
    name =~ /(.*) \(.*\)/
    name_and_version_without_codename = $1
    "#{name_and_version_without_codename} (#{architecture})"
  end
end

class OsOpenSuse13_1 < OsOpenSuse
  def self.canonical_name
    "openSUSE 13.1 (Bottle)"
  end

  def self.buildable_systems
    [OsSles11, OsOpenSuse13_1]
  end
end

class OsOpenSuse13_2 < OsOpenSuse
  def self.canonical_name
    "openSUSE 13.2 (Harlequin)"
  end

  def self.buildable_systems
    [OsSles11, OsOpenSuse13_1, OsOpenSuse13_2]
  end
end

class OsOpenSuseTumbleweed < Os
  def display_name
    "#{name} (#{architecture})"
  end

  def self.canonical_name
    "openSUSE Tumbleweed"
  end

  def self.buildable_systems
    [OsOpenSuse13_2]
  end
end

class OsOpenSuseLeap < Os
  def display_name
    "#{name} (#{architecture})"
  end

  def self.canonical_name
    "openSUSE Leap"
  end

  def self.buildable_systems
    [OsOpenSuse13_2, OsOpenSuseLeap]
  end
end

class Rhel < Os
  def self.canonical_name
    "Red Hat Enterprise Linux Server"
  end

  def self.can_run_machinery?
    false
  end
end
