defmodule Korero.Task do
  @moduledoc """
  Reusable Ash fragment for host-owned tasks and their generic queue lifecycle.

  Use `fragments: [Korero.Task]` on an Ash resource. The fragment supplies
  attributes, actions, code interfaces, request-key identity, optimistic
  revisions, AshStateMachine transitions, and the AshOban extension. It supplies
  no data layer, domain, table, tenancy, authorization policy, default trigger,
  or Oban supervisor. The host supplies a static domain and may define native
  AshOban triggers for explicitly selected typed actions on this resource,
  using its existing Oban instance. Worker reads and actions remain subject to
  host authorization; trusted worker actors are a host decision.

  Messages own communication state; tasks own requested work. A task may stand
  alone or refer to an attached resource by an opaque registry key and identity.
  Standalone completion is supported. Attached completion fails closed until a
  real typed target-action contract is provided: the domain resource must own
  its authorization, guards, state transition, and effects.

  Current resource records are authoritative. History is never replayed to
  reconstruct task state. Scheduling dependency relationships and lead/lag,
  task-level execution attempts, attached-resource dispatch, replication, and
  semantic journal integration are separate future boundaries. Oban owns job
  delivery and retries; a job's completion does not complete the task unless
  the explicitly configured Ash action does so. Delivery does not make external
  effects atomic or exactly-once. There is no snapshot-restoring undo.

  This task contract is one part of Korero's complete UI-and-communication
  package, not the product's outer boundary. Future classification connects
  tasks, conversations, artifacts, topics, interests, and events through
  many-to-many relationships. The current classification string is a queue
  hint, not an ontology or an authorization rule. Topic membership never
  widens participant visibility or grants access to an attached resource.
  """

  alias Ash.Error.Changes.InvalidAttribute

  @open_states [:queued, :in_progress, :deferred, :blocked]
  @request_identity_fields [
    :task_type,
    :task_type_version,
    :request_source_resource,
    :request_source_key,
    :target_resource,
    :target_key
  ]
  @create_attributes [
    :task_type,
    :task_type_version,
    :title,
    :description,
    :request_source_resource,
    :request_source_key,
    :target_resource,
    :target_key,
    :classification,
    :priority,
    :assignee_key,
    :due_at,
    :next_action_at
  ]

  use Spark.Dsl.Fragment, of: Ash.Resource, extensions: [AshStateMachine, AshOban]

  state_machine do
    initial_states([:queued])
    default_initial_state(:queued)
    state_attribute(:status)

    transitions do
      transition(:start, from: [:queued, :deferred, :blocked], to: :in_progress)
      transition(:defer, from: @open_states, to: :deferred)
      transition(:block, from: @open_states, to: :blocked)
      transition(:complete, from: @open_states, to: :completed)
      transition(:cancel, from: @open_states, to: :cancelled)
    end
  end

  code_interface do
    define :create
    define :request
    define :read
    define :by_id, args: [:id]
    define :by_request_key, args: [:request_key], not_found_error?: false
    define :open
    define :assign
    define :prioritize
    define :start
    define :defer
    define :block
    define :complete
    define :cancel
  end

  actions do
    read :read do
      primary? true
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end

    read :by_request_key do
      argument :request_key, :string,
        allow_nil?: false,
        constraints: [allow_empty?: false]

      get? true
      filter expr(request_key == ^arg(:request_key))
    end

    read :open do
      filter expr(status in @open_states)
      prepare build(sort: [priority: :asc_nils_last, inserted_at: :asc])
    end

    create :create do
      primary? true
      accept @create_attributes
      validate &Korero.Task.validate_optional_pairs/2
    end

    create :request do
      accept [:request_key | @create_attributes]
      validate present(:request_key)
      validate &Korero.Task.validate_optional_pairs/2

      upsert? true
      upsert_identity :unique_request_key
      upsert_fields []

      change after_action(&Korero.Task.verify_idempotent_request/3)
    end

    update :assign do
      description "Assigns queue ownership without implying that work has started"
      require_atomic? false
      accept [:assignee_key]
      validate attribute_in(:status, @open_states)
    end

    update :prioritize do
      description "Changes this task's position in the active work queue"
      require_atomic? false
      accept [:priority]
      validate attribute_in(:status, @open_states)
    end

    update :start do
      description "Starts work on an open task"
      require_atomic? false
      accept [:assignee_key]
      change transition_state(:in_progress)
      change before_action(&Korero.Task.prepare_start/2)
      change set_attribute(:next_action_at, nil)
    end

    update :defer do
      require_atomic? false
      accept [:next_action_at, :assignee_key, :disposition]
      validate present(:next_action_at)
      change transition_state(:deferred)
    end

    update :block do
      require_atomic? false
      accept [:assignee_key, :disposition]
      change transition_state(:blocked)
    end

    update :complete do
      description "Completes standalone work; attached work requires the typed target dispatcher"
      require_atomic? false
      accept [:disposition, :completed_by_key]
      change transition_state(:completed)
      change before_action(&Korero.Task.prepare_completion/2)
      change set_attribute(:priority, nil)
      change set_attribute(:next_action_at, nil)
    end

    update :cancel do
      require_atomic? false
      accept [:disposition, :cancelled_by_key]
      change transition_state(:cancelled)
      change set_attribute(:priority, nil)
      change set_attribute(:next_action_at, nil)
      change before_action(&Korero.Task.prepare_cancellation/2)
    end
  end

  changes do
    change optimistic_lock(:revision), on: :update
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :request_key, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
    end

    attribute :task_type, :string do
      allow_nil? false
      default "generic"
      public? true
      constraints allow_empty?: false
    end

    attribute :task_type_version, :integer do
      allow_nil? false
      default 1
      public? true
      constraints min: 1
      description "Pins the workflow contract version used by this task occurrence"
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints allow_empty?: false
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
    end

    attribute :request_source_resource, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
      description "Stable registry key for the requesting Ash resource, not a module name"
    end

    attribute :request_source_key, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
      description "Opaque stable identity understood by the request source"
    end

    attribute :target_resource, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
      description "Stable registry key for the target Ash resource, not a module name"
    end

    attribute :target_key, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
      description "Opaque stable identity understood by the target resource"
    end

    attribute :classification, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
    end

    attribute :priority, :integer do
      public? true
      constraints min: 0
    end

    attribute :assignee_key, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
    end

    attribute :due_at, :utc_datetime_usec do
      public? true
    end

    attribute :next_action_at, :utc_datetime_usec do
      public? true
    end

    attribute :disposition, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_by_key, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
    end

    attribute :cancelled_at, :utc_datetime_usec do
      public? true
    end

    attribute :cancelled_by_key, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: false
    end

    attribute :revision, :integer do
      allow_nil? false
      default 1
      public? true
      constraints min: 1
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_request_key, [:request_key]
  end

  @doc """
  Completes a standalone task idempotently through a host resource's Ash actions.

  The supplied resource is a trusted module using this fragment, never a module
  resolved from a persisted target string. Actor, tenant, and authorization
  options are forwarded to both the read and transition actions.
  """
  @spec complete_by_request_key(module(), String.t(), map(), keyword()) ::
          {:ok, Ash.Resource.Record.t()} | {:error, term()}
  def complete_by_request_key(resource, request_key, attributes \\ %{}, options \\ []) do
    transition_by_request_key(resource, request_key, :completed, attributes, options, :complete)
  end

  @doc "Cancels a requested task idempotently through a host resource's Ash actions."
  @spec cancel_by_request_key(module(), String.t(), map(), keyword()) ::
          {:ok, Ash.Resource.Record.t()} | {:error, term()}
  def cancel_by_request_key(resource, request_key, attributes \\ %{}, options \\ []) do
    transition_by_request_key(resource, request_key, :cancelled, attributes, options, :cancel)
  end

  @doc false
  def prepare_start(changeset, _context) do
    started_at = Ash.Changeset.get_data(changeset, :started_at) || DateTime.utc_now()
    Ash.Changeset.force_change_attribute(changeset, :started_at, started_at)
  end

  @doc false
  def prepare_completion(changeset, _context) do
    if attached?(changeset.data) do
      Ash.Changeset.add_error(changeset,
        field: :target_resource,
        message: "attached tasks require the typed target dispatcher"
      )
    else
      completed_at = DateTime.utc_now()

      changeset
      |> ensure_started_at(completed_at)
      |> Ash.Changeset.force_change_attribute(:completed_at, completed_at)
    end
  end

  @doc false
  def prepare_cancellation(changeset, _context) do
    Ash.Changeset.force_change_attribute(changeset, :cancelled_at, DateTime.utc_now())
  end

  defp attached?(%{target_resource: target_resource, target_key: target_key}) do
    not is_nil(target_resource) and not is_nil(target_key)
  end

  defp ensure_started_at(changeset, completed_at) do
    case Ash.Changeset.get_data(changeset, :started_at) do
      %DateTime{} -> changeset
      nil -> Ash.Changeset.force_change_attribute(changeset, :started_at, completed_at)
    end
  end

  defp transition_by_request_key(
         resource,
         request_key,
         terminal_status,
         attributes,
         options,
         transition
       ) do
    case resource.by_request_key(request_key, options) do
      {:ok, nil} ->
        {:error, :task_not_found}

      {:ok, %{status: ^terminal_status} = task} ->
        {:ok, task}

      {:ok, task} ->
        case apply(resource, transition, [task, attributes, options]) do
          {:ok, transitioned} ->
            {:ok, transitioned}

          {:error, _error} = transition_error ->
            return_terminal_after_concurrent_retry(
              resource,
              request_key,
              terminal_status,
              options,
              transition_error
            )
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp return_terminal_after_concurrent_retry(
         resource,
         request_key,
         terminal_status,
         options,
         transition_error
       ) do
    case resource.by_request_key(request_key, options) do
      {:ok, %{status: ^terminal_status} = task} -> {:ok, task}
      _other -> transition_error
    end
  end

  @doc false
  def validate_optional_pairs(changeset, _context) do
    with :ok <-
           validate_optional_pair(changeset, :request_source_resource, :request_source_key),
         :ok <- validate_optional_pair(changeset, :target_resource, :target_key) do
      :ok
    end
  end

  defp validate_optional_pair(changeset, resource_field, key_field) do
    resource = Ash.Changeset.get_attribute(changeset, resource_field)
    key = Ash.Changeset.get_attribute(changeset, key_field)

    if is_nil(resource) == is_nil(key) do
      :ok
    else
      {:error, field: resource_field, message: "must be provided together with #{key_field}"}
    end
  end

  @doc false
  def verify_idempotent_request(changeset, task, _context) do
    mismatches =
      Enum.reject(@request_identity_fields, fn field ->
        Ash.Changeset.get_attribute(changeset, field) == Map.fetch!(task, field)
      end)

    if mismatches == [] do
      {:ok, task}
    else
      {:error,
       InvalidAttribute.exception(
         field: :request_key,
         value: task.request_key,
         message:
           "already identifies a different task (mismatched #{Enum.join(mismatches, ", ")})"
       )}
    end
  end
end
