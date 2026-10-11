defmodule Korero.Test.RunnerTask do
  @moduledoc false
  use Ash.Resource,
    domain: Korero.Test.CoreDomain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Korero.Test.CoreIdentities],
    fragments: [Korero.Task, Korero.Runner]

  @behaviour Korero.Runner
  def korero_task_resource, do: __MODULE__

  def korero_task_actions,
    do: %{{"reading.article_invitation", 1} => {__MODULE__, :run_invitation}}

  ets do
    private? true
  end

  attributes do
    attribute :owner_id, :uuid, allow_nil?: false, writable?: false
  end

  changes do
    change fn changeset, context ->
             Ash.Changeset.force_change_attribute(changeset, :owner_id, context.actor.id)
           end,
           on: :create
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:read, :update]) do
      authorize_if expr(owner_id == ^actor(:id))
    end

    policy action_type(:action) do
      authorize_if actor_present()
    end
  end

  actions do
    action :run_invitation, :map do
      argument :task_id, :uuid, allow_nil?: false
      argument :expected_revision, :integer, allow_nil?: false

      run fn input, context ->
        with {:ok, task} <-
               Ash.get(__MODULE__, input.arguments.task_id,
                 actor: context.actor,
                 authorize?: true
               ),
             true <- task.revision == input.arguments.expected_revision do
          {:ok, %{task_id: task.id, actor_id: context.actor.id, revision: task.revision}}
        else
          {:error, error} -> {:error, error}
          _ -> {:error, "stale command"}
        end
      end
    end
  end
end
