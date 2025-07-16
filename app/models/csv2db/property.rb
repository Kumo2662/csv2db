module Csv2db
  class Property < ApplicationRecord
    enum :building_type, { apartment: 0, house: 1, mansion: 2 }, validate: true

    validates :name, presence: true
    validates :room_number, presence: true, unless: :house?
  end
end
