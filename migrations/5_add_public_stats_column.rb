Sequel.migration do
  change do
    alter_table(:tests) do
      add_column :public_stats, FalseClass, default: false, null: false
    end
  end
end
