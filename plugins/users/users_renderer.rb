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

class UsersRenderer < Renderer
  def content(description)
    return unless description.users

    list do
      description.users.each do |user|
        info = user.comment.empty? ? "N/A" : user.comment
        uid = user.uid || "N/A"
        gid = user.gid || "N/A"
        item "#{user.name} (#{info}, uid: #{uid}, gid: #{gid}, shell: #{user.shell})"
      end
    end
  end

  def display_name
    "Users"
  end
end
