defmodule Bank.Accounts do
  @moduledoc """
  The Accounts context.

  Provides a thin API around the Account schema for listing and creating accounts.
  """

  import Ecto.Query, warn: false
  alias Bank.Repo
  alias Bank.Accounts.Account

  @doc """
  List all accounts.
  """
  def list_accounts do
    Repo.all(from(a in Account, order_by: [desc: a.inserted_at]))
  end

  @doc """
  Create an account with attrs.
  """
  def create_account(attrs \\ %{}) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Return an Account changeset for forms.
  """
  def change_account(%Account{} = account, attrs \\ %{}) do
    Account.changeset(account, attrs)
  end

  @doc """
  Update an account with new attrs.
  """
  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete an account.
  """
  def delete_account(%Account{} = account) do
    Repo.delete(account)
  end
end
