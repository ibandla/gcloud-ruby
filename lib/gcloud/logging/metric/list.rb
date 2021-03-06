# Copyright 2016 Google Inc. All rights reserved.
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


require "delegate"

module Gcloud
  module Logging
    class Metric
      ##
      # Metric::List is a special case Array with additional values.
      class List < DelegateClass(::Array)
        ##
        # If not empty, indicates that there are more records that match
        # the request and this value should be passed to continue.
        attr_accessor :token

        ##
        # @private Create a new Metric::List with an array of Metric instances.
        def initialize arr = []
          super arr
        end

        ##
        # Whether there is a next page of metrics.
        #
        # @return [Boolean]
        #
        # @example
        #   require "gcloud"
        #
        #   gcloud = Gcloud.new
        #   logging = gcloud.logging
        #
        #   metrics = logging.metrics
        #   if metrics.next?
        #     next_metrics = metrics.next
        #   end
        #
        def next?
          !token.nil?
        end

        ##
        # Retrieve the next page of metrics.
        #
        # @return [Sink::List]
        #
        # @example
        #   require "gcloud"
        #
        #   gcloud = Gcloud.new
        #   logging = gcloud.logging
        #
        #   metrics = dataset.metrics
        #   if metrics.next?
        #     next_metrics = metrics.next
        #   end
        #
        def next
          return nil unless next?
          ensure_service!
          grpc = @service.list_metrics token: token, max: @max
          self.class.from_grpc grpc, @service
        end

        ##
        # Retrieves all metrics by repeatedly loading {#next} until {#next?}
        # returns `false`. Calls the given block once for each metric, which is
        # passed as the parameter.
        #
        # An Enumerator is returned if no block is given.
        #
        # This method may make several API calls until all metrics are
        # retrieved. Be sure to use as narrow a search criteria as possible.
        # Please use with caution.
        #
        # @param [Integer] request_limit The upper limit of API requests to make
        #   to load all metrics. Default is no limit.
        # @yield [metric] The block for accessing each metric.
        # @yieldparam [Metric] metric The metric object.
        #
        # @return [Enumerator]
        #
        # @example Iterating each metric by passing a block:
        #   require "gcloud"
        #
        #   gcloud = Gcloud.new
        #   logging = gcloud.logging
        #   metrics = logging.metrics
        #
        #   metrics.all do |metric|
        #     puts "#{metric.name}: #{metric.filter}"
        #   end
        #
        # @example Using the enumerator by not passing a block:
        #   require "gcloud"
        #
        #   gcloud = Gcloud.new
        #   logging = gcloud.logging
        #   metrics = logging.metrics
        #
        #   all_names = metrics.all.map do |metric|
        #     metric.name
        #   end
        #
        # @example Limit the number of API calls made:
        #   require "gcloud"
        #
        #   gcloud = Gcloud.new
        #   logging = gcloud.logging
        #   metrics = logging.metrics
        #
        #   metrics.all(request_limit: 10) do |metric|
        #     puts "#{metric.name}: #{metric.filter}"
        #   end
        #
        def all request_limit: nil
          request_limit = request_limit.to_i if request_limit
          unless block_given?
            return enum_for(:all, request_limit: request_limit)
          end
          results = self
          loop do
            results.each { |r| yield r }
            if request_limit
              request_limit -= 1
              break if request_limit < 0
            end
            break unless results.next?
            results = results.next
          end
        end

        ##
        # @private New Metric::List from a
        # Google::Logging::V2::ListLogMetricsResponse object.
        def self.from_grpc grpc_list, service, max = nil
          metrics = new(Array(grpc_list.metrics).map do |grpc_metric|
            Metric.from_grpc grpc_metric, service
          end)
          token = grpc_list.next_page_token
          token = nil if token == ""
          metrics.instance_variable_set "@token", token
          metrics.instance_variable_set "@service", service
          metrics.instance_variable_set "@max", max
          metrics
        end

        protected

        ##
        # @private Raise an error unless an active connection to the service is
        # available.
        def ensure_service!
          fail "Must have active connection to service" unless @service
        end
      end
    end
  end
end
