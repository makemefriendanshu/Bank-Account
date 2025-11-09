defmodule BankWeb.AccountLive.Index do
  use BankWeb, :live_view

  alias Bank.Accounts
  alias Bank.Accounts.Account

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Bank.PubSub, "accounts:updates")
    accounts = Accounts.list_accounts()
    changeset = Accounts.change_account(%Account{})

    {:ok,
     socket
     |> assign(:accounts, accounts)
     |> assign(:form, to_form(changeset, as: :account))
     |> assign(:edit_modal_open, false)
     |> assign(:edit_account, nil)
     |> assign(:edit_form, nil)
     |> assign(:credit_modal_open, false)
     |> assign(:debit_modal_open, false)
     |> assign(:transaction_modal_open, false)
     |> assign(:transaction_account, nil)
     |> assign(:transactions, [])
     |> assign(:credit_form, nil)
     |> assign(:debit_form, nil)}
  end

  @impl true
  def handle_event("open_credit_modal", %{"id" => id}, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))

    if account do
      form = to_form(%{"amount" => ""}, as: :credit)
      random_str = :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
      modal_uid = "#{:erlang.unique_integer([:positive, :monotonic])}-#{random_str}"

      {:noreply,
       socket
       |> assign(:credit_modal_open, true)
       |> assign(:transaction_account, account)
       |> assign(:credit_form, form)
       |> assign(:modal_uid, modal_uid)}
    else
      {:noreply, put_flash(socket, :error, "Account not found")}
    end
  end

  @impl true
  def handle_event("open_debit_modal", %{"id" => id}, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))

    if account do
      form = to_form(%{"amount" => ""}, as: :debit)
      random_str = :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
      modal_uid = "#{:erlang.unique_integer([:positive, :monotonic])}-#{random_str}"

      {:noreply,
       socket
       |> assign(:debit_modal_open, true)
       |> assign(:transaction_account, account)
       |> assign(:debit_form, form)
       |> assign(:modal_uid, modal_uid)}
    else
      {:noreply, put_flash(socket, :error, "Account not found")}
    end
  end

  @impl true
  def handle_event("close_credit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:credit_modal_open, false)
     |> assign(:transaction_account, nil)
     |> assign(:credit_form, nil)
     |> assign(:modal_uid, nil)}
  end

  @impl true
  def handle_event("close_debit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:debit_modal_open, false)
     |> assign(:transaction_account, nil)
     |> assign(:debit_form, nil)
     |> assign(:modal_uid, nil)}
  end

  @impl true
  def handle_event("credit", %{"credit" => %{"amount" => amount}}, socket) do
    account = socket.assigns.transaction_account

    case Accounts.credit_account(account, amount) do
      {:ok, _updated} ->
        BankWeb.PageBroadcaster.broadcast_update("accounts:updates")
        accounts = Accounts.list_accounts()

        {:noreply,
         socket
         |> assign(:accounts, accounts)
         |> assign(:credit_modal_open, false)
         |> assign(:transaction_account, nil)
         |> assign(:credit_form, nil)
         |> put_flash(:info, "Credited successfully")}

      _ ->
        {:noreply, put_flash(socket, :error, "Credit failed")}
    end
  end

  @impl true
  def handle_event("debit", %{"debit" => %{"amount" => amount}}, socket) do
    account = socket.assigns.transaction_account

    case Accounts.debit_account(account, amount) do
      {:ok, _updated} ->
        BankWeb.PageBroadcaster.broadcast_update("accounts:updates")
        accounts = Accounts.list_accounts()

        {:noreply,
         socket
         |> assign(:accounts, accounts)
         |> assign(:debit_modal_open, false)
         |> assign(:transaction_account, nil)
         |> assign(:debit_form, nil)
         |> put_flash(:info, "Debited successfully")}

      {:error, :insufficient_funds} ->
        {:noreply, put_flash(socket, :error, "Insufficient funds")}

      _ ->
        {:noreply, put_flash(socket, :error, "Debit failed")}
    end
  end

  @impl true
  def handle_event("show_transactions", %{"id" => id}, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))

    if account do
      transactions = Accounts.list_transactions(account)

      {:noreply,
       socket
       |> assign(:transaction_modal_open, true)
       |> assign(:transaction_account, account)
       |> assign(:transactions, transactions)}
    else
      {:noreply, put_flash(socket, :error, "Account not found")}
    end
  end

  @impl true
  def handle_event("close_transaction_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:transaction_modal_open, false)
     |> assign(:transaction_account, nil)
     |> assign(:transactions, [])}
  end

  # --- All handle_event/3 clauses grouped together ---
  @impl true
  def handle_event("delete_account", %{"id" => id}, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))

    if account do
      {:ok, _} = Accounts.delete_account(account)
      BankWeb.PageBroadcaster.broadcast_update("accounts:updates")
    end

    accounts = Accounts.list_accounts()
    {:noreply, assign(socket, :accounts, accounts)}
  end

  @impl true
  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))

    if account do
      changeset = Accounts.change_account(account)

      {:noreply,
       socket
       |> assign(:edit_modal_open, true)
       |> assign(:edit_account, account)
       |> assign(:edit_form, to_form(changeset, as: :edit_account))}
    else
      {:noreply, put_flash(socket, :error, "Account not found")}
    end
  end

  @impl true
  def handle_event("close_edit_modal", _params, socket) do
    changeset = Accounts.change_account(%Account{})

    {:noreply,
     socket
     |> assign(:edit_modal_open, false)
     |> assign(:edit_account, nil)
     |> assign(:edit_form, nil)
     |> assign(:form, to_form(changeset, as: :account))}
  end

  @impl true
  def handle_event("validate_edit", %{"edit_account" => params}, socket) do
    account = socket.assigns.edit_account
    # Always use the latest struct for validation
    changeset =
      if account do
        Accounts.change_account(account, params)
      else
        Accounts.change_account(%Account{}, params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :edit_form, to_form(changeset, as: :edit_account))}
  end

  @impl true
  def handle_event("save_edit", %{"edit_account" => %{"id" => id} = params}, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))

    case Accounts.update_account(account, params) do
      {:ok, _updated} ->
        # Broadcast update to all LiveViews
        BankWeb.PageBroadcaster.broadcast_update("accounts:updates")
        accounts = Accounts.list_accounts()

        {:noreply,
         socket
         |> assign(:accounts, accounts)
         |> assign(:edit_modal_open, false)
         |> assign(:edit_account, nil)
         |> assign(:edit_form, nil)
         |> put_flash(:info, "Account updated")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset, as: :edit_account))}
    end
  end

  @impl true
  def handle_event("validate", %{"account" => account_params}, socket) do
    changeset =
      %Account{}
      |> Accounts.change_account(account_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"account" => account_params}, socket) do
    case Accounts.create_account(account_params) do
      {:ok, _account} ->
        # Broadcast update to all LiveViews
        BankWeb.PageBroadcaster.broadcast_update("accounts:updates")
        accounts = Accounts.list_accounts()

        changeset = Accounts.change_account(%Account{})

        {:noreply,
         socket
         |> put_flash(:info, "Account created")
         |> assign(:accounts, accounts)
         |> assign(:form, to_form(changeset, as: :account))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :account))}
    end
  end

  @impl true
  def handle_info({:page_update, _payload}, socket) do
    accounts = Accounts.list_accounts()
    {:noreply, assign(socket, :accounts, accounts)}
  end
end
