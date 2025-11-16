

defmodule BankWeb.AccountLive.Index do
  require Logger
  use BankWeb, :live_view
  alias Bank.Accounts
  alias Bank.Accounts.Account

  # --- All handle_event/3 clauses grouped together ---
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

        changeset = Accounts.change_account(%Account{}) |> Map.put(:action, :insert)

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
  def handle_event("filter_chart", params, socket) do
    user_id = Map.get(params, "user_id", "")
    type = Map.get(params, "type", "")
    start_date = Map.get(params, "start_date", "")
    end_date = Map.get(params, "end_date", "")

    chart_user_id = if user_id == "", do: nil, else: String.to_integer(user_id)
    chart_type = if type == "", do: nil, else: type
    chart_start_date = if start_date == "", do: nil, else: start_date
    chart_end_date = if end_date == "", do: nil, else: end_date

    # Filter transactions for the chart only
    chart_transactions = Bank.Accounts.list_all_transactions_filtered(chart_user_id, chart_start_date, chart_end_date, chart_type)
    chart_data = build_chart_data(chart_transactions, chart_user_id)

    {:noreply,
      socket
      |> assign(:chart_user_id, chart_user_id)
      |> assign(:chart_type, chart_type)
      |> assign(:chart_start_date, chart_start_date)
      |> assign(:chart_end_date, chart_end_date)
      |> assign(:chart_data, chart_data)
    }
  end

  @impl true
  def handle_event("toggle_chart_filters", _params, socket), do: {:noreply, assign(socket, :show_chart_filters, !Map.get(socket.assigns, :show_chart_filters, false))}

  @impl true
  def handle_event("toggle_filters", _params, socket), do: {:noreply, assign(socket, :show_filters, !socket.assigns.show_filters)}

  @impl true
  def handle_event("validate_import", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("open_credit_modal", %{"id" => id} = _params, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))
    if account do
      form = to_form(%{"amount" => "", "reason" => ""}, as: :credit)
      random_str = :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
      modal_uid = "#{:erlang.unique_integer([:positive, :monotonic])}-#{random_str}"
      {:noreply,
       socket
       |> assign(:credit_modal_open, true)
       |> assign(:transaction_account, account)
       |> assign(:credit_form, form)
       |> assign(:modal_uid, modal_uid)}
    else
      changeset = Accounts.change_account(%Account{})
      {:noreply,
        socket
        |> put_flash(:error, "Account not found")
        |> assign(:form, to_form(changeset, as: :account))}
    end
  end

  @impl true
  def handle_event("open_debit_modal", %{"id" => id} = _params, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))
    if account do
      form = to_form(%{"amount" => "", "reason" => ""}, as: :debit)
      random_str = :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
      modal_uid = "#{:erlang.unique_integer([:positive, :monotonic])}-#{random_str}"
      {:noreply,
       socket
       |> assign(:debit_modal_open, true)
       |> assign(:transaction_account, account)
       |> assign(:debit_form, form)
       |> assign(:modal_uid, modal_uid)}
    else
      changeset = Accounts.change_account(%Account{})
      {:noreply,
        socket
        |> put_flash(:error, "Account not found")
        |> assign(:form, to_form(changeset, as: :account))}
    end
  end

  @impl true
  def handle_event("close_credit_modal", _params, socket), do: {:noreply, socket |> assign(:credit_modal_open, false) |> assign(:transaction_account, nil) |> assign(:credit_form, nil) |> assign(:modal_uid, nil)}

  @impl true
  def handle_event("close_debit_modal", _params, socket), do: {:noreply, socket |> assign(:debit_modal_open, false) |> assign(:transaction_account, nil) |> assign(:debit_form, nil) |> assign(:modal_uid, nil)}

  @impl true
  def handle_event("credit", %{"credit" => %{"amount" => amount}}, socket) do
    account = socket.assigns.transaction_account
    reason = socket.assigns.credit_form[:reason].value
    case Accounts.credit_account(account, amount, reason) do
      {:ok, _updated} ->
        BankWeb.PageBroadcaster.broadcast_update("accounts:updates")
        accounts = Accounts.list_accounts()
        account_id = socket.assigns[:filter_account_id]
        start_date = socket.assigns[:filter_start_date]
        end_date = socket.assigns[:filter_end_date]
        type = socket.assigns[:filter_type]
        all_transactions = Bank.Accounts.list_all_transactions_filtered(account_id, start_date, end_date, type)
        {:noreply,
         socket
         |> assign(:accounts, accounts)
         |> assign(:all_transactions, all_transactions)
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
    reason = socket.assigns.debit_form[:reason].value
    case Accounts.debit_account(account, amount, reason) do
      {:ok, _updated} ->
        BankWeb.PageBroadcaster.broadcast_update("accounts:updates")
        accounts = Accounts.list_accounts()
        account_id = socket.assigns[:filter_account_id]
        start_date = socket.assigns[:filter_start_date]
        end_date = socket.assigns[:filter_end_date]
        type = socket.assigns[:filter_type]
        all_transactions = Bank.Accounts.list_all_transactions_filtered(account_id, start_date, end_date, type)
        {:noreply,
         socket
         |> assign(:accounts, accounts)
         |> assign(:all_transactions, all_transactions)
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
  def handle_event("show_transactions", %{"id" => id} = _params, socket) do
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
  def handle_event("close_transaction_modal", _params, socket), do: {:noreply, socket |> assign(:transaction_modal_open, false) |> assign(:transaction_account, nil) |> assign(:transactions, [])}

  @impl true
  def handle_event("delete_account", %{"id" => id} = _params, socket) do
    account = Enum.find(socket.assigns.accounts, &("#{&1.id}" == id))
    if account do
      {:ok, _} = Accounts.delete_account(account)
      BankWeb.PageBroadcaster.broadcast_update("accounts:updates")
    end
    accounts = Accounts.list_accounts()
    changeset = Accounts.change_account(%Account{})
    {:noreply,
      socket
      |> assign(:accounts, accounts)
      |> assign(:form, to_form(changeset, as: :account))}
  end

  @impl true
  def handle_event("open_edit_modal", %{"id" => id} = _params, socket) do
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
  def handle_event("filter_transactions", %{"account_id" => account_id, "start_date" => start_date, "end_date" => end_date, "type" => type}, socket) do
   account_id = if account_id == "", do: nil, else: account_id
   start_date = if start_date == "", do: nil, else: start_date
   end_date = if end_date == "", do: nil, else: end_date
   type = if type == "", do: nil, else: type
   account_id = if account_id, do: String.to_integer(account_id), else: nil
   all_transactions = Bank.Accounts.list_all_transactions_filtered(account_id, start_date, end_date, type)
   chart_data = build_chart_data(all_transactions, socket.assigns.chart_user_id)
   {:noreply,
    socket
    |> assign(:all_transactions, all_transactions)
    |> assign(:filter_account_id, account_id)
    |> assign(:filter_start_date, start_date)
    |> assign(:filter_end_date, end_date)
    |> assign(:filter_type, type)
    |> assign(:chart_data, chart_data)}
  end

  @impl true
  def handle_event("import_xls", _params, socket) do
    consume_uploaded_entries(socket, :xls_file, fn %{path: path}, _entry ->
      result =
        case Xlsxir.multi_extract(path) do
          {:ok, tid} ->
            rows = Xlsxir.get_list(tid)
            Enum.each(rows, fn row ->
              name = extract_account_holder_name(row)
              if is_binary(name) and String.trim(name) != "" and name != "nil" do
                IO.puts("Account Holder Name: #{inspect(name)}")
              end
            end)
            Xlsxir.close(tid)
            :ok
          [ok: tid] ->
            rows = Xlsxir.get_list(tid)
            Enum.each(rows, fn row ->
              name = extract_account_holder_name(row)
              if is_binary(name) and String.trim(name) != "" and name != "nil" do
                IO.puts("Account Holder Name: #{inspect(name)}")
              end
            end)
            Xlsxir.close(tid)
            :ok
          _err ->
            :error
        end
      {:ok, result}
    end)
    {:noreply, put_flash(socket, :info, "Import complete (stub)")}
  end
  # --- End of handle_event/3 group ---

  @impl true
  def mount(_params, _session, socket) do
    accounts = Accounts.list_accounts()
    changeset = Accounts.change_account(%Account{})
    all_transactions = Bank.Accounts.list_all_transactions_filtered(nil, nil, nil, nil)
    chart_data = build_chart_data(all_transactions, nil)
    socket =
      socket
      |> assign(:accounts, accounts)
      |> assign(:form, to_form(changeset, as: :account))
      |> assign(:all_transactions, all_transactions)
      |> assign(:chart_data, chart_data)
      |> assign(:show_filters, false)
      |> assign(:show_chart_filters, false)
      |> assign(:chart_user_id, nil)
      |> assign(:chart_type, nil)
      |> assign(:chart_start_date, nil)
      |> assign(:chart_end_date, nil)
      |> assign(:filter_account_id, nil)
      |> assign(:filter_start_date, nil)
      |> assign(:filter_end_date, nil)
      |> assign(:filter_type, nil)
      |> assign(:edit_modal_open, false)
      |> assign(:edit_account, nil)
      |> assign(:edit_form, nil)
      |> assign(:transaction_modal_open, false)
      |> assign(:transaction_account, nil)
      |> assign(:transactions, [])
      |> assign(:debit_modal_open, false)
      |> assign(:debit_form, nil)
      |> assign(:credit_modal_open, false)
      |> assign(:credit_form, nil)
      |> assign(:modal_uid, nil)
      |> allow_upload(:xls_file, accept: ~w(.xlsx .xls), max_entries: 1)
    {:ok, socket}
  end

  # ...existing code...


  defp build_chart_data(transactions, user_id) do
    # Get all accounts from assigns (fall back to DB if not present)
    accounts =
      case Process.get(:accounts) do
        nil -> Bank.Accounts.list_accounts()
        accs -> accs
      end

    filtered =
      if user_id do
        Enum.filter(transactions, &(&1.account_id == user_id))
      else
        transactions
      end


    # Group by date (YYYY-MM-DD)
    grouped =
      filtered
      |> Enum.group_by(fn tx ->
        tx.inserted_at
        |> NaiveDateTime.to_date()
        |> Date.to_iso8601()
      end)

    dates = grouped |> Map.keys() |> Enum.sort()
    credits = Enum.map(dates, fn date ->
      grouped[date]
      |> Enum.filter(&(&1.type == "credit"))
      |> Enum.map(& &1.amount)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
      |> Decimal.to_float()
    end)
    debits = Enum.map(dates, fn date ->
      grouped[date]
      |> Enum.filter(&(&1.type == "debit"))
      |> Enum.map(& &1.amount)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
      |> Decimal.to_float()
    end)

    # Determine initial amount
    initial_amount =
      if user_id do
        accounts
        |> Enum.filter(&(&1.id == user_id))
        |> Enum.map(& &1.amount)
        |> List.first()
        |> case do
          nil -> Decimal.new(0)
          val -> val
        end
      else
        accounts
        |> Enum.map(& &1.amount)
        |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
      end

    # Subtract all credits and add all debits to get the initial amount at the start of the graph
    # (since account.amount is current, not initial)
    all_credits =
      filtered
      |> Enum.filter(&(&1.type == "credit"))
      |> Enum.map(& &1.amount)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    all_debits =
      filtered
      |> Enum.filter(&(&1.type == "debit"))
      |> Enum.map(& &1.amount)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    graph_initial = Decimal.sub(Decimal.add(initial_amount, all_debits), all_credits)

    # Calculate running amount per date (sorted by date), starting from graph_initial
    running_amounts =
      dates
      |> Enum.reduce({[], graph_initial}, fn date, {acc, prev_amount} ->
        txs = grouped[date]
        day_total =
          txs
          |> Enum.reduce(prev_amount, fn tx, amt ->
            case tx.type do
              "credit" -> Decimal.add(amt, tx.amount)
              "debit" -> Decimal.sub(amt, tx.amount)
              _ -> amt
            end
          end)
        {[Decimal.to_float(day_total) | acc], day_total}
      end)
      |> elem(0)
      |> Enum.reverse()

    %{
      labels: dates,
      datasets: [
        %{
          label: "Credit",
          data: credits,
          borderColor: "#22c55e",
          backgroundColor: "#22c55e33",
          tension: 0.3
        },
        %{
          label: "Debit",
          data: debits,
          borderColor: "#f59e42",
          backgroundColor: "#f59e4233",
          tension: 0.3
        },
        %{
          label: "Amount",
          data: running_amounts,
          borderColor: "#3b82f6",
          backgroundColor: "#3b82f633",
          tension: 0.3,
          yAxisID: "y1"
        }
      ]
    }
    |> Jason.encode!()
  end


  defp extract_account_holder_name(row) do
    row
    |> Enum.filter(&is_binary/1)
    |> Enum.map(fn cell ->
      cell_clean = String.replace(cell, ~r/\s+/, " ") |> String.trim()
      Regex.run(~r/(?:MR\.?|MRS\.?)[ ]+([A-Za-z ]+)/i, cell_clean, capture: :all_but_first)
    end)
    |> Enum.find(fn
      [name] when is_binary(name) -> true
      _ -> false
    end)
    |> case do
      [name] ->
        name
        |> String.split()
        |> Enum.find(fn part -> String.length(part) >= 3 end)
        |> case do
          nil -> nil
          n -> String.capitalize(String.trim(n))
        end
      _ ->
        row_str = row |> Enum.map(&to_string/1) |> Enum.join(" ") |> String.replace(~r/\s+/, " ") |> String.trim()
        match = Regex.run(~r/(?:MR\.?|MRS\.?)[ ]+([A-Za-z ]+)/i, row_str, capture: :all_but_first)
        case match do
          [name] ->
            name
            |> String.split()
            |> Enum.find(fn part -> String.length(part) >= 3 end)
            |> case do
              nil -> nil
              n -> String.capitalize(String.trim(n))
            end
          _ -> nil
        end
    end
  end



  @impl true
  def handle_info({:page_update, _payload}, socket) do
    accounts = Accounts.list_accounts()
    # Re-apply filters
    account_id = socket.assigns[:filter_account_id]
    start_date = socket.assigns[:filter_start_date]
    end_date = socket.assigns[:filter_end_date]
    type = socket.assigns[:filter_type]

    all_transactions =
      Bank.Accounts.list_all_transactions_filtered(account_id, start_date, end_date, type)

    {:noreply,
     socket
    |> assign(:accounts, accounts)
    |> assign(:all_transactions, all_transactions)}
  end

end
