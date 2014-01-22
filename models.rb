class Test < Sequel::Model
  one_to_many :cases
  one_to_many :choices
  many_to_one :user
end

class Case < Sequel::Model
  many_to_one :test
  one_to_many :choices
  many_to_one :user
end

class Choice < Sequel::Model
  many_to_one :test
  many_to_one :case
  many_to_one :user
end

class User < Sequel::Model
  one_to_many :tests
  one_to_many :cases
  one_to_many :choices
end
