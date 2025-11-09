defmodule Bank.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add(:amount, :decimal, null: false)
      add(:type, :string, null: false)
      add(:account_id, references(:accounts, on_delete: :delete_all), null: false)
      timestamps()
    end

    create(index(:transactions, [:account_id]))
  end
end
