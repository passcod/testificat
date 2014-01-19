Sequel.migration do
  change do
    alter_table(:tests) do
      set_column_type :key, String, size: 128
    end
  end
end
