require 'rails_helper'

RSpec.describe Csv2db::Property, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      property = described_class.new(name: 'Test', building_type: :apartment, room_number: '101')
      expect(property).to be_valid
    end

    it 'is invalid without a name' do
      property = described_class.new(building_type: :apartment, room_number: '101')
      expect(property).not_to be_valid
      expect(property.errors[:name]).to include("can't be blank")
    end

    it 'requires room_number unless building_type is house' do
      property = described_class.new(name: 'Test', building_type: :apartment)
      expect(property).not_to be_valid
      expect(property.errors[:room_number]).to include("can't be blank")

      property = described_class.new(name: 'Test', building_type: :house)
      expect(property).to be_valid
    end
  end

  describe 'enum building_type' do
    it 'defines correct enum values' do
      expect(described_class.building_types).to eq({ 'apartment' => 0, 'house' => 1, 'mansion' => 2 })
    end
  end
end
