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

class Html
  # Creates a new thread running a sinatra webserver which serves the local system descriptions
  # The Thread object is returned so that the caller can `.join` it until it's finished.
  def self.run_server(system_description_store, opts)
    Thread.new do
      Server.set :system_description_store, system_description_store
      Server.set :port, opts[:port] || 7585
      Server.set :bind, opts[:ip] || "localhost"
      Server.set :public_folder, File.join(Machinery::ROOT, "html")

      if opts[:ip] != "localhost" && opts[:ip] != "127.0.0.1"
        Machinery::Ui.puts <<EOF
Warning:
You specified an IP address other than '127.0.0.1', your server may be reachable from the network.
This could lead to confidential data like passwords or private keys being readable by others.
EOF
      end

      begin
        setup_output_redirection
        begin
          Server.run!
        rescue Errno::EADDRINUSE
          servefailed_error = <<-EOF.chomp
Port #{Server.settings.port} is already in use.
Stop the already running server on port #{Server.settings.port} or specify a new port by using --port option.
EOF
          raise Machinery::Errors::ServeFailed, servefailed_error
        end
        remove_output_redirection
      rescue => e
        remove_output_redirection
        # Re-raise exception in main thread
        Thread.main.raise e
      end
    end
  end

  def self.when_server_ready(ip, port, &block)
    20.times do
      begin
        TCPSocket.new(ip, port).close
        block.call
        return
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        sleep 0.1
      end
    end
    raise Machinery::Errors::MachineryError, "The web server did not come up in time."
  end

  def self.setup_output_redirection
    @orig_stdout = STDOUT.clone
    @orig_stderr = STDERR.clone
    server_log = File.join(Machinery::DEFAULT_CONFIG_DIR, "webserver.log")
    STDOUT.reopen server_log, "w"
    STDERR.reopen server_log, "w"
  end

  def self.remove_output_redirection
    STDOUT.reopen @orig_stdout
    STDERR.reopen @orig_stderr
  end
end
