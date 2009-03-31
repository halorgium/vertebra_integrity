require "integrity"

module VertebraIntegrity
  module Actors
    class Continuous < Vertebra::Actor
      def initialize(*args)
        super

        @config_path, @announce_ircnet, @announce_channel = args.first
        Integrity.new(@config_path)
      end

      bind_op "/ci/build", :build
      desc "/ci/build", "Run the tests for a project"
      def build(operation, args)
        repository = args["repository"]
        project_name = repository.last
        puts "Running tests for #{project_name}"
        project = Integrity::Project.first(:permalink => project_name) || raise("Project #{project_name.inspect} not found")

        Thread.start do
          commit = project.send(:create_commit_from, args["commit"])
          build = project.build(commit.identifier)

          if build.successful?
            send_to_irc "[#{project.name}] CI Build #{commit.identifier} passed :D"
          else
            send_to_irc "[#{project.name}] CI Build #{commit.identifier} failed :("
          end
        end

        true
      end

      def send_to_irc(message)
        puts "About to send: #{message}"
        args = {
          :ircnet => Vertebra::Utils.resource(@announce_ircnet),
          :channel => Vertebra::Utils.resource(@announce_channel),
          :message => message
        }
        @agent.request("/irc/push", :single, args) do |response|
          puts "message pushed: #{response.inspect}"
        end
      end
    end
  end
end
