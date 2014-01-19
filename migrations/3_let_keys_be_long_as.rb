Sequel.migration do
  change do
    alter_table(:tests) do
      set_column_type :key, String, text: true
    end
  end
end
