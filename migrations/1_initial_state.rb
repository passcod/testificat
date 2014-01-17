Sequel.migration do
  change do
    create_table(:tests) do
      primary_key :id, type: Bignum
      String :key, null: false, size: 512
      String :title, null: true, size: 140
      DateTime :date_created
    end

    create_table(:cases) do
      primary_key :id, type: Bignum
      foreign_key :test_id, :tests
      String :title, null: true, size: 140
      String :content, null: false, text: true
      String :type, default: 'mkd', null: false, size: 3
      DateTime :date_created
    end

    create_table(:choices) do
      primary_key :id
      foreign_key :test_id, :tests
      foreign_key :case_id, :cases
      DateTime :date_created
    end
  end
end
