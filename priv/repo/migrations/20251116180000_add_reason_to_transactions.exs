defmodule Bank.Repo.Migrations.AddReasonToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :reason, :string
    end
  end
end
