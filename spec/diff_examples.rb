require 'helper/spec_helper'

shared_examples 'bora#diff' do
  describe "#diff" do
    context "stack does not exist" do
      before do
        @config["templates"]["web"]["stacks"]["prod"]["params"] = {"Port" => "80"}
        @stack = setup_stack("web-prod", status: :not_created)
        setup_parameters(@stack, [])
      end

      it "shows the whole template as being new" do
        current_template = nil
        new_template = %Q({\n"aaa": "1",\n"bbb": "2",\n"ccc": "3"\n})
        setup_templates(current_template, new_template)
        output = bora.run(@config, "diff", "web-prod")
        expect(output).to include("+Port - 80")
        expect(output).to match(/\+\s*"aaa": "1"/)
        expect(output).to match(/\+\s*"bbb": "2"/)
        expect(output).to match(/\+\s*"ccc": "3"/)
      end
    end

    context "stack exists and template has changed" do
      before do
        @config["templates"]["web"]["stacks"]["prod"]["params"] = {"Port" => "80", "Timeout" => "60"}
        @stack = setup_stack("web-prod", status: :create_complete)
        setup_parameters(@stack, [{parameter_key: "Port", parameter_value: "22"}])
        setup_changeset(@stack)
      end

      it "shows the difference between the current and new templates" do
        current_template = %Q({"aaa": "1",\n"ccc": "3"})
        new_template = %Q({"aaa": "1",\n"bbb": "2",\n"ccc": "3"})
        setup_templates(current_template, new_template)
        output = bora.run(@config, "diff", "web-prod")
        expect(output).to include("Parameters")
        expect(output).to include("-Port - 22")
        expect(output).to include("+Port - 80")
        expect(output).to include("+Timeout - 60")
        expect(output).not_to match(/\+\s*"aaa": "1"/)
        expect(output).to match(/\+\s*"bbb": "2"/)
        expect(output).not_to match(/\+\s*"ccc": "3"/)
        expect(output).to include("Modify", "MySG")
      end

      it "shows a configurable number of context lines around each diff" do
        if bora.is_a?(BoraCli)
          current_template = %Q({"line1": "1",\n"line2": "1",\n"line3": "1",\n"line4": "1",\n"line5": "1",\n"line6": "1",\n"line7": "1",\n"line8": "1",\n"line9": "1",\n"lineA": "1",\n"lineB": "1",\n"lineC": "1",\n"lineD": "1",\n"lineE": "1"})
          new_template     = %Q({"line1": "1",\n"line2": "1",\n"line3": "1",\n"line4": "1",\n"line5": "1",\n"line6": "1",\n"line7": "1",\n"line88": "1",\n"line9": "1",\n"lineA": "1",\n"lineB": "1",\n"lineC": "1",\n"lineD": "1",\n"lineE": "1"})
          setup_templates(current_template, new_template)
          output = bora.run(@config, "diff", "web-prod", "--context", "5")
          expect(output).not_to include("line2")
          expect(output).to include("line3")
          expect(output).to match(/-\s*"line8"/)
          expect(output).to match(/\+\s*"line88"/)
          expect(output).to include("lineD")
          expect(output).not_to include("lineE")
        end
      end
    end

    context "stack exists but template is the same" do
      before do
        @config["templates"]["web"]["stacks"]["prod"]["params"] = {"Port" => "22"}
        @stack = setup_stack("web-prod", status: :create_complete)
        setup_parameters(@stack, [{parameter_key: "Port", parameter_value: "22"}])
        setup_changeset(@stack, has_changes: false)
      end

      it "Indicates if the template has not changed" do
        current_template = %Q({"aaa": "1",\n"ccc": "3"})
        new_template = current_template
        setup_templates(current_template, new_template)
        output = bora.run(@config, "diff", "web-prod")
        expect(output).to include("Parameters")
        expect(output).to include(Bora::Stack::STACK_DIFF_PARAMETERS_UNCHANGED_MESSAGE)
        expect(output).to include(Bora::Stack::STACK_DIFF_TEMPLATE_UNCHANGED_MESSAGE)
        expect(output).to include(Bora::Stack::STACK_DIFF_NO_CHANGES_MESSAGE)
      end
    end

    context "stack exists without parameters" do
      before do
        @stack = setup_stack("web-prod", status: :create_complete)
        setup_parameters(@stack, [])
        setup_changeset(@stack)
      end

      it "does not show the parameters section in the diff" do
        current_template = %Q({"aaa": "1",\n"ccc": "3"})
        new_template = current_template
        setup_templates(current_template, new_template)
        output = bora.run(@config, "diff", "web-prod")
        expect(output).not_to include("Parameters")
      end
    end

    context "stack with default parameters" do
      before do
        @stack = setup_stack("web-prod", status: :create_complete)
        setup_parameters(@stack, [{parameter_key: "Port", parameter_value: "22"}])
        setup_changeset(@stack)
      end

      it "recognises parameters with defaults as not being changed" do
        current_template = {
          "Parameters" => {
            "Port" => {
              "Type" => "String",
              "Default" => "22"
            }
          }
        }.to_json
        new_template = current_template
        setup_templates(current_template, new_template)
        output = bora.run(@config, "diff", "web-prod")
        expect(output).to include(Bora::Stack::STACK_DIFF_PARAMETERS_UNCHANGED_MESSAGE)
        expect(output).to include(Bora::Stack::STACK_DIFF_TEMPLATE_UNCHANGED_MESSAGE)
      end
    end

    def setup_templates(current_template, new_template)
      expect(@stack).to receive(:template).and_return(current_template)
      setup_template(@config, "web", new_template)
    end

    def setup_changeset(stack, has_changes: true)
      change_set_name = "test-change-set"
      change_set_response = {
        status: "CREATE_COMPLETE",
        status_reason: "Finished",
        execution_status: "AVAILABLE",
        description: "My change set",
        creation_time: Time.parse("2016-07-21 15:01:00")
      }
      if has_changes
        change_set_response[:changes] = [
          {
            resource_change: {
              action: "Modify",
              resource_type: "AWS::EC2::SecurityGroup",
              logical_resource_id: "MySG"
            }
          }
        ]
      else
        change_set_response[:changes] = []
      end
      change_set = setup_create_change_set(stack, nil, change_set_response)
      allow(stack).to receive(:delete_change_set)
      change_set
    end
  end
end
