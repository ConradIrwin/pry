class Pry
  module ExtendedCommands

    UserCommandAPI = Pry::CommandSet.new do

      command "define-command", "To honor Mon-Ouie" do |arg|
        next output.puts("Provide an arg!") if arg.nil?

        prime_string = "command #{arg_string}\n"
        command_string = pry.r(target, prime_string)

        eval_string.replace <<-HERE
          _pry_.commands.instance_eval do
            #{command_string}
          end
        HERE

      end

    end
  end
end
