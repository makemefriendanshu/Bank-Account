defmodule Bank.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field(:name, :string)
    field(:amount, :decimal, default: 0)

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :amount])
    |> validate_required([:name, :amount])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
  end
end
