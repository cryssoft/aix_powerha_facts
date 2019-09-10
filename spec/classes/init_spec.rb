require 'spec_helper'
describe 'powerha_custom_fact' do
  context 'with default values for all parameters' do
    it { should contain_class('powerha_custom_fact') }
  end
end
