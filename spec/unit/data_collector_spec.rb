#
# Author:: Adam Leff (<adamleff@chef.io)
# Author:: Ryan Cragun (<ryan@chef.io>)
#
# Copyright:: Copyright 2012-2016, Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.expand_path("../../spec_helper", __FILE__)
require "chef/data_collector"

describe Chef::DataCollector::Reporter do
  let(:reporter) { described_class.new }

  describe '#run_started' do
    before do
      allow(reporter).to receive(:update_run_status)
      allow(reporter).to receive(:send_to_data_collector)
    end

    it "updates the run status" do
      expect(reporter).to receive(:update_run_status).with("test_run_status")
      reporter.run_started("test_run_status")
    end

    it "sends the RunStart serializer output to the Data Collector server" do
      expect(Chef::DataCollector::Serializers::RunStart).to receive(:new).and_return("run_start_data")
      expect(reporter).to receive(:send_to_data_collector).with("run_start_data")
      reporter.run_started("test_run_status")
    end
  end

  describe '#run_completed' do
    it 'sends the run completion' do
      expect(reporter).to receive(:send_run_completion)
      reporter.run_completed("fake_node")
    end
  end

  describe '#run_failed' do
    it "updates the exception and sends the run completion" do
      expect(reporter).to receive(:update_exception).with("test_exception")
      expect(reporter).to receive(:send_run_completion)
      reporter.run_failed("test_exception")
    end
  end

  describe '#resource_current_state_loaded' do
    let(:new_resource)     { double("new_resource") }
    let(:action)           { double("action") }
    let(:current_resource) { double("current_resource") }

    context "when resource is a nested resource" do
      it "does not update the resource report" do
        allow(reporter).to receive(:nested_resource?).and_return(true)
        expect(reporter).not_to receive(:update_current_resource_report)
        reporter.resource_current_state_loaded(new_resource, action, current_resource)
      end
    end

    context "when resource is not a nested resource" do
      it "updates the resource report" do
        allow(reporter).to receive(:nested_resource?).and_return(false)
        expect(Chef::DataCollector::ResourceReport).to receive(:for_current_resource).with(
          new_resource,
          action,
          current_resource)
        .and_return("resource_report")
        expect(reporter).to receive(:update_current_resource_report).with("resource_report")
        reporter.resource_current_state_loaded(new_resource, action, current_resource)
      end
    end
  end

  describe '#resource_up_to_date' do
    let(:new_resource) { double("new_resource") }
    let(:action)       { double("action") }

    before do
      allow(reporter).to receive(:increment_resource_count)
      allow(reporter).to receive(:nested_resource?)
      allow(reporter).to receive(:update_current_resource_report)
    end

    it "increments the resource count" do
      expect(reporter).to receive(:increment_resource_count)
      reporter.resource_up_to_date(new_resource, action)
    end

    context "when the resource is a nested resource" do
      it "does not nil out the current resource report" do
        allow(reporter).to receive(:nested_resource?).with(new_resource).and_return(true)
        expect(reporter).not_to receive(:update_current_resource_report)
        reporter.resource_up_to_date(new_resource, action)
      end
    end

    context "when the resource is not a nested resource" do
      it "does not nil out the current resource report" do
        allow(reporter).to receive(:nested_resource?).with(new_resource).and_return(false)
        expect(reporter).to receive(:update_current_resource_report).with(nil)
        reporter.resource_up_to_date(new_resource, action)
      end
    end
  end

  describe '#resource_skipped' do
    let(:new_resource) { double("new_resource") }
    let(:action)       { double("action") }
    let(:conditional)  { double("conditional") }

    before do
      allow(reporter).to receive(:increment_resource_count)
      allow(reporter).to receive(:nested_resource?)
      allow(reporter).to receive(:update_current_resource_report)
    end

    it "increments the resource count" do
      expect(reporter).to receive(:increment_resource_count)
      reporter.resource_skipped(new_resource, action, conditional)
    end

    context "when the resource is a nested resource" do
      it "does not nil out the current resource report" do
        allow(reporter).to receive(:nested_resource?).with(new_resource).and_return(true)
        expect(reporter).not_to receive(:update_current_resource_report)
        reporter.resource_skipped(new_resource, action, conditional)
      end
    end

    context "when the resource is not a nested resource" do
      it "does not nil out the current resource report" do
        allow(reporter).to receive(:nested_resource?).with(new_resource).and_return(false)
        expect(reporter).to receive(:update_current_resource_report).with(nil)
        reporter.resource_skipped(new_resource, action, conditional)
      end
    end
  end

  describe '#resource_updated' do
    it "increments the resource count" do
      expect(reporter).to receive(:increment_resource_count)
      reporter.resource_updated("new_resource", "action")
    end
  end

  describe '#resource_failed' do
    let(:new_resource) { double("new_resource") }
    let(:action)       { double("action") }
    let(:exception)    { double("exception") }
    let(:error_mapper) { double("error_mapper")}

    before do
      allow(reporter).to receive(:increment_resource_count)
      allow(reporter).to receive(:update_error_description)
      allow(reporter).to receive(:update_current_resource_report)
      allow(Chef::Formatters::ErrorMapper).to receive(:resource_failed).and_return(error_mapper)
      allow(error_mapper).to receive(:for_json)
    end

    it "increments the resource count" do
      expect(reporter).to receive(:increment_resource_count)
      reporter.resource_failed(new_resource, action, exception)
    end

    it "updates the error description" do
      expect(Chef::Formatters::ErrorMapper).to receive(:resource_failed).with(
        new_resource,
        action,
        exception
      ).and_return(error_mapper)
      expect(error_mapper).to receive(:for_json).and_return("error_description")
      expect(reporter).to receive(:update_error_description).with("error_description")
      reporter.resource_failed(new_resource, action, exception)
    end

    context "when the resource is not a nested resource" do
      it "updates the current resource report" do
        allow(reporter).to receive(:nested_resource?).with(new_resource).and_return(false)
        expect(Chef::DataCollector::ResourceReport).to receive(:for_exception).with(
          new_resource,
          action,
          exception
        ).and_return("resource_exception_report")
        expect(reporter).to receive(:update_current_resource_report).with("resource_exception_report")
        reporter.resource_failed(new_resource, action, exception)
      end
    end

    context "when the resource is a nested resource" do
      it "does not update the current resource report" do
        allow(reporter).to receive(:nested_resource?).with(new_resource).and_return(true)
        expect(reporter).not_to receive(:update_current_resource_report)
        reporter.resource_failed(new_resource, action, exception)
      end
    end
  end

  describe '#resource_completed' do
    let(:new_resource)    { double("new_resource") }
    let(:resource_report) { double("resource_report") }

    before do
      allow(reporter).to receive(:add_updated_resource)
      allow(reporter).to receive(:update_current_resource_report)
      allow(resource_report).to receive(:finish)
    end

    context "when there is no current resource report" do
      it "does not add the updated resource" do
        allow(reporter).to receive(:current_resource_report).and_return(nil)
        expect(reporter).not_to receive(:add_updated_resource)
        reporter.resource_completed(new_resource)
      end
    end

    context "when there is a current resource report" do
      before do
        allow(reporter).to receive(:current_resource_report).and_return(resource_report)
      end

      context "when the resource is a nested resource" do
        it "does not add the updated resource" do
          allow(reporter).to receive(:nested_resource?).with(new_resource).and_return(true)
          expect(reporter).not_to receive(:add_updated_resource)
          reporter.resource_completed(new_resource)
        end
      end

      context "when the resource is not a nested resource" do
        before do
          allow(reporter).to receive(:nested_resource?).with(new_resource).and_return(false)
        end

        it "marks the current resource report as finished" do
          expect(resource_report).to receive(:finish)
          reporter.resource_completed(new_resource)
        end

        it "adds the resource to the updated resource list" do
          expect(reporter).to receive(:add_updated_resource).with(resource_report)
          reporter.resource_completed(new_resource)
        end

        it "nils out the current resource report" do
          expect(reporter).to receive(:update_current_resource_report).with(nil)
          reporter.resource_completed(new_resource)
        end
      end
    end
  end

  describe '#run_list_expanded' do
    it "sets the expanded run list" do
      reporter.run_list_expanded("test_run_list")
      expect(reporter.expanded_run_list).to eq("test_run_list")
    end
  end

  describe '#run_list_expand_failed' do
    let(:node)         { double("node") }
    let(:error_mapper) { double("error_mapper") }
    let(:exception)    { double("exception") }

    it "updates the error description" do
      expect(Chef::Formatters::ErrorMapper).to receive(:run_list_expand_failed).with(
        node,
        exception
      ).and_return(error_mapper)
      expect(error_mapper).to receive(:for_json).and_return("error_description")
      expect(reporter).to receive(:update_error_description).with("error_description")
      reporter.run_list_expand_failed(node, exception)
    end
  end

  describe '#cookbook_resolution_failed' do
    let(:error_mapper)      { double("error_mapper") }
    let(:exception)         { double("exception") }
    let(:expanded_run_list) { double("expanded_run_list") }

    it "updates the error description" do
      expect(Chef::Formatters::ErrorMapper).to receive(:cookbook_resolution_failed).with(
        expanded_run_list,
        exception
      ).and_return(error_mapper)
      expect(error_mapper).to receive(:for_json).and_return("error_description")
      expect(reporter).to receive(:update_error_description).with("error_description")
      reporter.cookbook_resolution_failed(expanded_run_list, exception)
    end

  end

  describe '#cookbook_sync_failed' do
    let(:cookbooks)    { double("cookbooks") }
    let(:error_mapper) { double("error_mapper") }
    let(:exception)    { double("exception") }

    it "updates the error description" do
      expect(Chef::Formatters::ErrorMapper).to receive(:cookbook_sync_failed).with(
        cookbooks,
        exception
      ).and_return(error_mapper)
      expect(error_mapper).to receive(:for_json).and_return("error_description")
      expect(reporter).to receive(:update_error_description).with("error_description")
      reporter.cookbook_sync_failed(cookbooks, exception)
    end
  end

  describe '#disable_reporter_on_error' do
    context "when no exception is raise by the block" do
      it "does not disable the reporter" do
        expect(reporter).not_to receive(:disable_data_collector_reporter)
        reporter.send(:disable_reporter_on_error) { true }
      end

      it "does not raise an exception" do
        expect { reporter.send(:disable_reporter_on_error) { true } }.not_to raise_error
      end
    end

    context "when an unexpected exception is raised by the block" do
      it "re-raises the exception" do
        expect { reporter.send(:disable_reporter_on_error) { raise RuntimeError, "bummer" } }.to raise_error(RuntimeError)
      end
    end

    [ Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError ].each do |exception_class|
      context "when the block raises a #{exception_class} exception" do
        it "disables the reporter" do
          expect(reporter).to receive(:disable_data_collector_reporter)
          reporter.send(:disable_reporter_on_error) { raise exception_class.new("bummer") }
        end

        context "when raise-on-failure is enabled" do
          it "logs an error and raises" do
            Chef::Config[:data_collector_raise_on_failure] = true
            expect(Chef::Log).to receive(:error)
            expect { reporter.send(:disable_reporter_on_error) { raise exception_class.new("bummer") } }.to raise_error(exception_class)
          end
        end

        context "when raise-on-failure is disabled" do
          it "logs a warning and does not raise an exception" do
            Chef::Config[:data_collector_raise_on_failure] = false
            expect(Chef::Log).to receive(:warn)
            expect { reporter.send(:disable_reporter_on_error) { raise exception_class.new("bummer") } }.not_to raise_error
          end
        end
      end
    end
  end
end
