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

require "storage_helper"

describe "Storage", :files, :storage do
  let :bucket do
    storage.bucket(bucket_name) ||
    storage.create_bucket(bucket_name)
  end
  let(:bucket_name) { $bucket_names.first }

  let(:files) do
    { logo: { path: "acceptance/data/CloudPlatform_128px_Retina.png" },
      big:  { path: "acceptance/data/three-mb-file.tif" } }
  end
  let(:filenames) { ["CloudLogo1", "CloudLogo2", "CloudLogo3"] }

  before do
    # always create the bucket and delete all files, just in case
    bucket.files.all.each(&:delete)

    uploaded = bucket.create_file files[:logo][:path], filenames[0]
    uploaded.copy filenames[1]
    uploaded.copy filenames[2]
  end

  after do
    bucket.files.each &:delete
  end

  it "get all files" do
    bucket.files.all.each do |file|
      file.must_be_kind_of Gcloud::Storage::File
    end
  end

  it "gets pages of files" do
    first_files = bucket.files max: 2
    first_files.next?.must_equal true
    first_files.each { |f| f.must_be_kind_of Gcloud::Storage::File }
    second_files = first_files.next
    second_files.each { |f| f.must_be_kind_of Gcloud::Storage::File }
  end

  it "gets all files with request_limit" do
    bucket.files(max: 2).all(request_limit: 1) do |file|
      file.must_be_kind_of Gcloud::Storage::File
    end
  end
end
