Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      DateTime :date_last_seen
      String :ips_used, text: true
      String :session_ids, text: true
    end

    alter_table(:choices) do
      add_foreign_key :user_id, :users
    end

    alter_table(:cases) do
      add_foreign_key :user_id, :users
    end

    alter_table(:tests) do
      add_foreign_key :user_id, :users
    end
  end
end
