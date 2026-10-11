defmodule Korero.Phoenix.Components do
  @moduledoc """
  Composable task Inbox presentation extracted, copy-first, from Calvin.

  The host supplies an authorized client projection, its mount path and slots
  for business actions, message implementation and rich-text composition.
  Calvin's original components remain operational beside this extraction.
  Presentation never reads a source or decides that an actor may execute work.
  """
  use Phoenix.Component

  alias Korero.Client.State

  attr(:client, :map, required: true)
  attr(:state, :map, required: true)
  attr(:inbox_path, :string, required: true)
  attr(:label, :string, default: "Inbox")
  attr(:navigation_open?, :boolean, default: true)
  attr(:can_compose?, :boolean, default: false)
  attr(:format_time, :any, default: &__MODULE__.format_time/1)

  slot(:toolbar)
  slot(:navigation_extra)
  slot(:thread_actions)
  slot(:focus)
  slot(:composer)
  slot(:classification)

  def workspace(assigns) do
    assigns =
      assign(
        assigns,
        :filter_form,
        to_form(
          %{
            "participant" => assigns.client.filter[:participant_param] || "self",
            "workflow" => assigns.client.filter[:workflow] || ""
          },
          as: :inbox_filter
        )
      )

    ~H"""
    <section id="korero-inbox" class="korero-inbox">
      <header class="korero-inbox__header">
        <div>
          <p class="korero-inbox__kicker">Work and conversations</p>
          <h1>{@label}</h1>
        </div>
        <div class="korero-inbox__toolbar">
          {render_slot(@toolbar)}
          <button :if={@can_compose?} id="inbox-new-message" type="button" phx-click="new_message">
            New message
          </button>
          <.form :if={Map.get(@client.filter, :configurable?, false)}
            for={@filter_form} id="inbox-filter" phx-change="filter_inbox">
            <label :if={Map.get(@client.filter, :participant_options, []) != []}>
              People
              <select id="inbox-participant" name={@filter_form[:participant].name}>
                <option :for={option <- @client.filter.participant_options}
                  value={option.value} selected={option.value == @filter_form[:participant].value}>
                  {option.label}
                </option>
              </select>
            </label>
            <label :if={Map.get(@client.filter, :workflow_options, []) != []}>
              Workflow
              <select id="inbox-workflow" name={@filter_form[:workflow].name}>
                <option :for={option <- @client.filter.workflow_options}
                  value={option.value} selected={option.value == @filter_form[:workflow].value}>
                  {option.label}
                </option>
              </select>
            </label>
          </.form>
        </div>
      </header>

      <.focus_workspace id="inbox-workspace" label={@label}
        navigation_open?={@navigation_open?} focused?={not is_nil(@state.selected_thread)}>
        <:navigation>
          <nav id="inbox-folders" aria-label="Work views">
            <button id="inbox-folder-toggle" type="button" phx-click="toggle_folders"
              aria-expanded={to_string(@navigation_open?)} aria-controls="inbox-folder-list">
              {if(@navigation_open?, do: "Collapse views", else: "Open views")}
            </button>
            <div id="inbox-folder-list">
              <.link :for={folder <- @client.folders}
                id={"inbox-folder-#{folder.key}"}
                patch={State.path(@inbox_path, @client.filter, folder: folder.key)}
                aria-current={if(folder.key == @state.current_folder, do: "page")}
                class="korero-inbox__folder">
                <span>{folder.label}</span><span>{folder.count}</span>
              </.link>
            </div>
            {render_slot(@navigation_extra)}
          </nav>
        </:navigation>
        <:queue>
          <div id="inbox-queue">
            <p :if={@state.folder_threads == []} id="inbox-empty" class="korero-inbox__empty">
              {if(@state.current_folder == "inbox", do: "Inbox zero", else: "Nothing here")}
            </p>
            <.thread_row :for={thread <- @state.visible_threads}
              thread={thread} client={@client} state={@state} inbox_path={@inbox_path}
              format_time={@format_time} />
            <section :if={@state.later_threads != []} id="inbox-later">
              <h2>Later</h2>
              <.thread_row :for={thread <- @state.later_threads} thread={thread}
                client={@client} state={@state} inbox_path={@inbox_path}
                format_time={@format_time} later? />
            </section>
            <.pagination client={@client} inbox_path={@inbox_path} folder={@state.current_folder} />
          </div>
        </:queue>
        <:focus>
          <div id="inbox-focus">
            {render_slot(@composer)}
            <%= if @state.selected_thread do %>
              <header class="korero-inbox__focus-header">
                <h2>{@state.selected_thread.subject}</h2>
                {render_slot(@thread_actions, @state.selected_thread)}
                {render_slot(@classification, @state.selected_thread)}
              </header>
              <%= if @focus != [] do %>
                {render_slot(@focus, @state.selected_thread)}
              <% else %>
                <article :for={entry <- @state.selected_thread.entries}
                  id={"inbox-entry-#{entry.source_kind}-#{entry.source_id}"}
                  class="korero-inbox__entry">
                  <header><strong>{entry.from}</strong><time>{@format_time.(entry.sent_at)}</time></header>
                  <p>{Map.get(entry, :body) || Map.get(entry, :preview)}</p>
                  <footer><span>{entry.app}</span><span>{entry.channel}</span></footer>
                </article>
              <% end %>
            <% else %>
              <p :if={@composer == []} id="inbox-select-item" class="korero-inbox__empty">
                Select a task or message
              </p>
            <% end %>
          </div>
        </:focus>
      </.focus_workspace>
    </section>
    """
  end

  attr(:label, :string, required: true)
  attr(:navigation_open?, :boolean, default: false)
  attr(:focused?, :boolean, default: false)
  attr(:rest, :global)
  slot(:navigation)
  slot(:queue, required: true)
  slot(:focus, required: true)

  def focus_workspace(assigns) do
    ~H"""
    <section class="korero-workspace" aria-label={@label}
      data-navigation={if(@navigation_open?, do: "open", else: "closed")}
      data-focus={if(@focused?, do: "active", else: "empty")} {@rest}>
      <aside :if={@navigation != []} data-workspace="navigation">{render_slot(@navigation)}</aside>
      <section data-workspace="queue">{render_slot(@queue)}</section>
      <article data-workspace="focus">{render_slot(@focus)}</article>
    </section>
    """
  end

  attr(:thread, :map, required: true)
  attr(:client, :map, required: true)
  attr(:state, :map, required: true)
  attr(:inbox_path, :string, required: true)
  attr(:format_time, :any, required: true)
  attr(:later?, :boolean, default: false)

  defp thread_row(assigns) do
    pagination = Map.get(assigns.client, :pagination, %{})

    assigns =
      assign(
        assigns,
        :href,
        State.path(assigns.inbox_path, assigns.client.filter,
          folder: assigns.state.current_folder,
          thread: assigns.thread.id,
          cursor: pagination[:cursor],
          direction: pagination[:direction]
        )
      )

    ~H"""
    <.link id={"inbox-thread-#{@thread.id}"} patch={@href} class="korero-workspace-item"
      data-selected={to_string(@state.selected_thread_id == @thread.id)}
      data-deferred={to_string(@later?)}
      data-unread={to_string(@thread.unread? or @thread.needs_action?)}
      aria-current={if(@state.selected_thread_id == @thread.id, do: "true")}>
      <div data-slot="heading"><strong>{@thread.from}</strong><time>{@format_time.(@thread.sent_at)}</time></div>
      <div data-slot="title">
        <span :if={@thread.unread? or @thread.needs_action?} data-slot="unread"
          data-action={to_string(@thread.needs_action?)} />
        <p>{@thread.subject}</p>
        <span :if={@thread.priority in [:urgent, :high]} class="korero-inbox__badge">{@thread.priority}</span>
      </div>
      <div data-slot="preview">{@thread.preview}</div>
      <div data-slot="metadata">
        <span data-role="classification">{@thread.classification}</span><span>{@thread.app}</span>
        <span :if={@later?}>Deferred</span>
        <span :if={length(@thread.entries) > 1}>{length(@thread.entries)} messages on this page</span>
      </div>
    </.link>
    """
  end

  attr(:client, :map, required: true)
  attr(:inbox_path, :string, required: true)
  attr(:folder, :string, required: true)

  defp pagination(assigns) do
    assigns = assign(assigns, :pagination, Map.get(assigns.client, :pagination, %{}))

    ~H"""
    <nav id="inbox-pagination" aria-label="Inbox pages">
      <.link :if={@pagination[:has_previous?] && @pagination[:previous_cursor]}
        id="inbox-previous-page"
        patch={State.path(@inbox_path, @client.filter, folder: @folder, cursor: @pagination.previous_cursor, direction: "previous")}>
        Previous
      </.link>
      <.link :if={@pagination[:has_next?] && @pagination[:next_cursor]}
        id="inbox-next-page"
        patch={State.path(@inbox_path, @client.filter, folder: @folder, cursor: @pagination.next_cursor, direction: "next")}>
        Next
      </.link>
    </nav>
    """
  end

  def format_time(nil), do: ""
  def format_time(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%b %-d · %H:%M UTC")
  def format_time(%NaiveDateTime{} = datetime), do: Calendar.strftime(datetime, "%b %-d · %H:%M")
end
