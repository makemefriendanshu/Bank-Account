defmodule Bank.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add(:name, :string, null: false)
      add(:amount, :decimal, precision: 12, scale: 2, null: false, default: 0)

      timestamps()
    end
  end
end
