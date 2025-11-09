defmodule BankWeb.AccountLive.Index do
  use BankWeb, :live_view

  alias Bank.Accounts
  alias Bank.Accounts.Account

  @impl true
  def mount(_params, _session, socket) do
    accounts = Accounts.list_accounts()
    changeset = Accounts.change_account(%Account{})

    {:ok,
     socket
     |> assign(:accounts, accounts)
     |> assign(:form, to_form(changeset, as: :new_account))
     |> assign(:edit_modal_open, false)
     |> assign(:edit_account, nil)
     |> assign(:edit_form, nil)}
  end

  @impl true
  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))
    changeset = Accounts.change_account(account)

    {:noreply,
     socket
     |> assign(:edit_modal_open, true)
     |> assign(:edit_account, account)
     |> assign(:edit_form, to_form(changeset))}
  end

  @impl true
  def handle_event("close_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:edit_modal_open, false)
     |> assign(:edit_account, nil)
     |> assign(:edit_form, nil)}
  end

  @impl true
  def handle_event("validate_edit", %{"account" => params}, socket) do
    changeset =
      socket.assigns.edit_account
      |> Accounts.change_account(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :edit_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_edit", %{"account" => %{"id" => id} = params}, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))

    case Accounts.update_account(account, params) do
      {:ok, _updated} ->
        accounts = Accounts.list_accounts()

        {:noreply,
         socket
         |> assign(:accounts, accounts)
         |> assign(:edit_modal_open, false)
         |> assign(:edit_account, nil)
         |> assign(:edit_form, nil)
         |> put_flash(:info, "Account updated")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset))}
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
        accounts = Accounts.list_accounts()

        changeset = Accounts.change_account(%Account{})

        {:noreply,
         socket
         |> put_flash(:info, "Account created")
         |> assign(:accounts, accounts)
         |> assign(:form, to_form(changeset, as: :new_account))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
