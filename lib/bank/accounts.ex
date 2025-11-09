defmodule Bank.Accounts do
  import Ecto.Query, warn: false
  alias Bank.Repo
  alias Bank.Accounts.Transaction

  @doc """
  List the latest N transactions across all accounts, with account preloaded.
  """
  def list_latest_transactions_with_account(limit) when is_integer(limit) and limit > 0 do
    from(t in Transaction,
      order_by: [desc: t.inserted_at],
      preload: [:account],
      limit: ^limit
    )
    |> Repo.all()
  end

  import Ecto.Query, warn: false
  alias Bank.Repo
  alias Bank.Accounts.Transaction

  @doc """
  Credit an account by amount and record transaction.
  """
  def credit_account(%Bank.Accounts.Account{} = account, amount)
      when is_number(amount) or is_binary(amount) do
    Repo.transaction(fn ->
      new_amount = Decimal.add(account.amount, Decimal.new(amount))

      {:ok, updated} =
        account
        |> Bank.Accounts.Account.changeset(%{amount: new_amount})
        |> Repo.update()

      %Transaction{}
      |> Transaction.changeset(%{amount: amount, type: "credit", account_id: account.id})
      |> Repo.insert!()

      updated
    end)
  end

  @doc """
  Debit an account by amount and record transaction.
  """
  def debit_account(%Bank.Accounts.Account{} = account, amount)
      when is_number(amount) or is_binary(amount) do
    Repo.transaction(fn ->
      new_amount = Decimal.sub(account.amount, Decimal.new(amount))

      if Decimal.compare(new_amount, 0) == :lt do
        Repo.rollback(:insufficient_funds)
      end

      {:ok, updated} =
        account
        |> Bank.Accounts.Account.changeset(%{amount: new_amount})
        |> Repo.update()

      %Transaction{}
      |> Transaction.changeset(%{amount: amount, type: "debit", account_id: account.id})
      |> Repo.insert!()

      updated
    end)
  end

  @doc """
  List all transactions for an account.
  """
  def list_transactions(%Bank.Accounts.Account{id: account_id}) do
    query =
      from(t in Transaction, where: t.account_id == ^account_id, order_by: [desc: t.inserted_at])

    Repo.all(query)
  end

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

  @doc """
  List all transactions across all accounts, ordered by inserted_at descending, with optional filters.
  Filters:
    - account_id: only transactions for this account
    - start_date: only transactions on/after this date (YYYY-MM-DD)
    - end_date: only transactions on/before this date (YYYY-MM-DD)
  """

  def list_all_transactions_filtered(
        account_id \\ nil,
        start_date \\ nil,
        end_date \\ nil,
        type \\ nil
      ) do
    query =
      from(t in Transaction,
        order_by: [desc: t.inserted_at],
        preload: [:account]
      )

    query =
      if account_id do
        from(t in query, where: t.account_id == ^account_id)
      else
        query
      end

    query =
      if start_date do
        {:ok, start_dt} = Date.from_iso8601(start_date)
        from(t in query, where: fragment("date(?)", t.inserted_at) >= ^start_dt)
      else
        query
      end

    query =
      if end_date do
        {:ok, end_dt} = Date.from_iso8601(end_date)
        from(t in query, where: fragment("date(?)", t.inserted_at) <= ^end_dt)
      else
        query
      end

    query =
      if type do
        from(t in query, where: t.type == ^type)
      else
        query
      end

    Repo.all(query)
  end

  def list_all_transactions do
    list_all_transactions_filtered(nil, nil, nil)
  end
end
