require "spec_helper"

describe ZMQP1::Awesome do
  it "is awesome" do
    ZMQP1::Awesome.new.describe.should be_awesome
  end
end
