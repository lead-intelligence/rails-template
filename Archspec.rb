architecture :rails

jobs.cannot_reference_constants "Current", because: "a job runs outside the request; pass the record instead"

%w[services forms decorators presenters components].each do |name|
  component name.to_sym, in: "app/#{name}/**/*.rb"
  public_send(name).must_be_empty because: "rich models: the logic lives in the model that owns it"
end
