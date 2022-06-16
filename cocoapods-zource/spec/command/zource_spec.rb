require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Zource do
    describe 'CLAide' do
      it 'registers it self' do
        Command.parse(%w{ zource }).should.be.instance_of Command::Zource
      end
    end
  end
end

