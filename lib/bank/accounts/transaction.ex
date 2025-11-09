defmodule Bank.Accounts.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field(:amount, :decimal)
    # "credit" or "debit"
    field(:type, :string)
    belongs_to(:account, Bank.Accounts.Account)
    timestamps()
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :type, :account_id])
    |> validate_required([:amount, :type, :account_id])
    |> validate_inclusion(:type, ["credit", "debit"])
    |> validate_number(:amount, greater_than: 0)
  end
end
