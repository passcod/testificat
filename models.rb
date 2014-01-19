class Test < Sequel::Model
  one_to_many :cases
  one_to_many :choices
end

class Case < Sequel::Model
  many_to_one :test
  one_to_many :choices
end

class Choice < Sequel::Model
  many_to_one :test
  many_to_one :case
end
