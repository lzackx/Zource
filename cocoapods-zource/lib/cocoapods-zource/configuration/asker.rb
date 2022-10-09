require "yaml"
require "cocoapods-zource/configuration/configuration"

module CocoapodsZource
  class Configuration
    class Asker
      def show_prompt
        print " > ".green
      end

      def ask_with_answer(question, last_answer)
        print "\n#{question}\n"

        print "Last: #{last_answer}\n" unless last_answer.nil?

        answer = ""
        loop do
          show_prompt
          answer = STDIN.gets.chomp.strip

          if answer.include?(",")
            answer = answer.split(",")
          end

          if answer == "" && !last_answer.nil?
            answer = last_answer
            print answer.yellow
            print "\n"
          end

          next if answer.empty?
          break
        end
        answer
      end

      def wellcome_message
        print <<~EOF

                Start configuring.
                Configuration file will be stored in project home path.
                File name is kind like zource.[environment].yml.
                Edit it if you want. 
                The default info is as follow：

                #{CocoapodsZource::Configuration::configuration.default_configuration.to_yaml}
              EOF
      end

      def done_message
        print "\n\nConfigruation file: #{CocoapodsZource::Configuration::configuration.configuration_file}\n".cyan
        print "\n#{CocoapodsZource::Configuration::configuration.configuration.to_yaml}\n".green
        print "\nDone.\n".green
      end
    end
  end
end
