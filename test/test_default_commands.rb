require 'helper'

describe "Pry::Commands" do

  after do
    $obj = nil
  end

  describe "hist" do
    push_first_hist_line = lambda do |hist, line|
      hist.push line
    end

    before do
      Readline::HISTORY.shift until Readline::HISTORY.empty?
      @hist = Readline::HISTORY
    end

    it 'should display the correct history' do
      push_first_hist_line.call(@hist, "'bug in 1.8 means this line is ignored'")
      @hist.push "hello"
      @hist.push "world"
      output = StringIO.new
      redirect_pry_io InputTester.new("hist", "exit"), output do
        pry
      end
      output.string.should =~ /hello\n.*world/
    end

    it 'should replay history correctly (single item)' do
      push_first_hist_line.call(@hist, ":hello")
      @hist.push ":blah"
      @hist.push ":bucket"
      @hist.push ":ostrich"
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --replay 1", "exit"), str_output) do
        pry
      end
      str_output.string.should =~ /blah/
    end

    it 'should replay a range of history correctly (range of items)' do
      push_first_hist_line.call(@hist, "'bug in 1.8 means this line is ignored'")
      @hist.push ":hello"
      @hist.push ":carl"
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --replay 0..2", "exit"), str_output) do
        pry
      end
      str_output.string.should =~ /:hello\n.*:carl/
    end

    it 'should grep for correct lines in history' do
      push_first_hist_line.call(@hist, "apple")
      @hist.push "abby"
      @hist.push "box"
      @hist.push "button"
      @hist.push "pepper"
      @hist.push "orange"
      @hist.push "grape"

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --grep o", "exit"), str_output) do
        pry
      end

      str_output.string.should =~ /\d:.*?box\n\d:.*?button\n\d:.*?orange/
    end

    it 'should return last N lines in history with --tail switch' do
      push_first_hist_line.call(@hist, "0")
      ("a".."z").each do |v|
        @hist.push v
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --tail 3", "exit"), str_output) do
        pry
      end

      str_output.string.each_line.count.should == 3
      str_output.string.should =~ /x\n\d+:.*y\n\d+:.*z/
    end

    # strangeness in this test is due to bug in Readline::HISTORY not
    # always registering first line of input
    it 'should return first N lines in history with --head switch' do
      push_first_hist_line.call(@hist, "0")
      ("a".."z").each do |v|
        @hist.push v
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --head 4", "exit"), str_output) do
        pry
      end

      str_output.string.each_line.count.should == 4
      str_output.string.should =~ /a\n\d+:.*b\n\d+:.*c/
    end

    # strangeness in this test is due to bug in Readline::HISTORY not
    # always registering first line of input
    it 'should show lines between lines A and B with the --show switch' do
      push_first_hist_line.call(@hist, "0")
      ("a".."z").each do |v|
        @hist.push v
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --show 1..4", "exit"), str_output) do
        pry
      end

      str_output.string.each_line.count.should == 4
      str_output.string.should =~ /b\n\d+:.*c\n\d+:.*d/
    end
  end

  describe "show-method" do
    it 'should output a method\'s source' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-method sample_method", "exit"), str_output) do
        pry
      end

      str_output.string.should =~ /def sample/
    end

    it 'should output a method\'s source with line numbers' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-method -l sample_method", "exit"), str_output) do
        pry
      end

      str_output.string.should =~ /\d+: def sample/
    end

    it 'should output a method\'s source if inside method without needing to use method name' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-method", "exit"), $str_output) do
          binding.pry
        end
      end
      o.sample

      $str_output.string.should =~ /def o.sample/
      $str_output = nil
    end

    it 'should output a method\'s source if inside method without needing to use method name, and using the -l switch' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-method -l", "exit"), $str_output) do
          binding.pry
        end
      end
      o.sample

      $str_output.string.should =~ /\d+: def o.sample/
      $str_output = nil
    end

    # dynamically defined method source retrieval is only supported in
    # 1.9 - where Method#source_location is native
    if RUBY_VERSION =~ /1.9/
      it 'should output a method\'s source for a method defined inside pry' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("def dyna_method", ":testing", "end", "show-method dyna_method", "exit"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def dyna_method/
        Object.remove_method :dyna_method
      end

      it 'should output a method\'s source for a method defined inside pry, even if exceptions raised before hand' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("bad code", "123", "bad code 2", "1 + 2", "def dyna_method", ":testing", "end", "show-method dyna_method", "exit"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def dyna_method/
        Object.remove_method :dyna_method
      end

      it 'should output an instance method\'s source for a method defined inside pry' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("class A", "def yo", "end", "end", "show-method A#yo", "exit"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def yo/
        Object.remove_const :A
      end

      it 'should output an instance method\'s source for a method defined inside pry using define_method' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("class A", "define_method(:yup) {}", "end", "end", "show-method A#yup", "exit"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /define_method\(:yup\)/
        Object.remove_const :A
      end
    end
  end

  describe "show-doc" do
    it 'should output a method\'s documentation' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-doc sample_method", "exit"), str_output) do
        pry
      end

      str_output.string.should =~ /sample doc/
    end

    it 'should output a method\'s documentation if inside method without needing to use method name' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-doc", "exit"), $str_output) do
          binding.pry
        end
      end
      o.sample

      $str_output.string.should =~ /sample doc/
      $str_output = nil
    end
  end


  describe "cd" do
    it 'should cd into simple input' do
      b = Pry.binding_for(Object.new)
      b.eval("x = :mon_ouie")

      redirect_pry_io(InputTester.new("cd x", "$obj = self", "exit"), StringIO.new) do
        b.pry
      end

      $obj.should == :mon_ouie
    end

    it 'should break out of session with cd ..' do
      b = Pry.binding_for(:outer)
      b.eval("x = :inner")

      redirect_pry_io(InputTester.new("cd x", "$inner = self;", "cd ..", "$outer = self", "exit"), StringIO.new) do
        b.pry
      end
      $inner.should == :inner
      $outer.should == :outer
    end

    it 'should break out to outer-most session with cd /' do
      b = Pry.binding_for(:outer)
      b.eval("x = :inner")

      redirect_pry_io(InputTester.new("cd x", "$inner = self;", "cd 5", "$five = self", "cd /", "$outer = self", "exit"), StringIO.new) do
        b.pry
      end
      $inner.should == :inner
      $five.should == 5
      $outer.should == :outer
    end

    it 'should start a session on TOPLEVEL_BINDING with cd ::' do
      b = Pry.binding_for(:outer)

      redirect_pry_io(InputTester.new("cd ::", "$obj = self", "exit"), StringIO.new) do
        5.pry
      end
      $obj.should == TOPLEVEL_BINDING.eval('self')
    end

    it 'should cd into complex input (with spaces)' do
      o = Object.new
      def o.hello(x, y, z)
        :mon_ouie
      end

      redirect_pry_io(InputTester.new("cd hello 1, 2, 3", "$obj = self", "exit"), StringIO.new) do
        o.pry
      end
      $obj.should == :mon_ouie
    end
  end

  # show-command only works in implementations that support Proc#source_location
  if Proc.method_defined?(:source_location)
    describe "show-command" do
      it 'should show source for an ordinary command' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command "foo" do
            :body_of_foo
          end
        end
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("show-command foo"), str_output) do
          Pry.new(:commands => set).rep
        end
        str_output.string.should =~ /:body_of_foo/
      end

      it 'should show source for a command with spaces in its name' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command "foo bar" do
            :body_of_foo_bar
          end
        end
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("show-command \"foo bar\""), str_output) do
          Pry.new(:commands => set).rep
        end
        str_output.string.should =~ /:body_of_foo_bar/
      end

      it 'should show source for a command by listing name' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command /foo(.*)/, "", :listing => "bar" do
            :body_of_foo_regex
          end
        end
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("show-command bar"), str_output) do
          Pry.new(:commands => set).rep
        end
        str_output.string.should =~ /:body_of_foo_regex/
      end
    end
  end

  describe "help" do
    it 'should display help for a specific command' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("help ls", "exit"), str_output) do
        pry
      end
      str_output.string.each_line.count.should == 1
      str_output.string.should =~ /ls --help/
    end

    it 'should display help for a regex command with a "listing"' do
      set = Pry::CommandSet.new do
        command /bar(.*)/, "Test listing", :listing => "foo" do
        end
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("help foo"), str_output) do
        Pry.new(:commands => set).rep
      end
      str_output.string.each_line.count.should == 1
      str_output.string.should =~ /Test listing/
    end

    it 'should display help for a command with a spaces in its name' do
      set = Pry::CommandSet.new do
        command "command with spaces", "description of a command with spaces" do
        end
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("help \"command with spaces\""), str_output) do
        Pry.new(:commands => set).rep
      end
      str_output.string.each_line.count.should == 1
      str_output.string.should =~ /description of a command with spaces/
    end

    it 'should display help for all commands with a description' do
      set = Pry::CommandSet.new do
        command /bar(.*)/, "Test listing", :listing => "foo" do; end
        command "b", "description for b", :listing => "foo" do; end
        command "c" do;end
        command "d", "" do;end
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("help"), str_output) do
        Pry.new(:commands => set).rep
      end
      str_output.string.should =~ /Test listing/
      str_output.string.should =~ /description for b/
      str_output.string.should =~ /No description/
    end
  end
end
