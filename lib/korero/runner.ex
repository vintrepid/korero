defmodule Korero.Runner do
  @moduledoc """
  Native Ash dispatch into a host's trusted, versioned task commands.

  Compose this fragment into an authorized host resource and implement the two
  callbacks below. Task type/version selects a static registered Ash generic
  action. No module, action, owner, recipient, target parameters or credential is
  accepted from a caller. Every task read and command retains actor and tenant
  authorization. An optional expected revision rejects stale UI intent.

  This boundary does not complete work or make its initial read transactional.
  The selected command must reload and authorize task/source/target inside its
  declared native Ash transaction, enforce immutable parameters and revisions,
  and persist an idempotent outcome. The host owns touched resources and durable
  delivery. No worker, provider or second job engine starts automatically.
  """
  use Spark.Dsl.Fragment, of: Ash.Resource

  @callback korero_task_resource() :: module()
  @callback korero_task_actions() :: %{{String.t(), pos_integer()} => {module(), atom()}}

  actions do
    action :run_task, :map do
      argument :task_id, :uuid, allow_nil?: false
      argument :expected_revision, :integer, constraints: [min: 1]
      run &Korero.Runner.run/2
    end
  end

  @doc false
  def run(input, context) do
    options = [actor: context.actor, tenant: context.tenant, authorize?: true]
    expected = Map.get(input.arguments, :expected_revision)

    with true <- not is_nil(context.actor),
         true <- function_exported?(input.resource, :korero_task_resource, 0),
         true <- function_exported?(input.resource, :korero_task_actions, 0),
         {:ok, task} <-
           Ash.get(input.resource.korero_task_resource(), input.arguments.task_id, options),
         %{task_type: type, task_type_version: version, revision: revision} <- task,
         :ok <- expected_revision(expected, revision),
         {resource, name} when is_atom(resource) and is_atom(name) <-
           Map.get(input.resource.korero_task_actions(), {type, version}),
         %{type: :action, arguments: arguments} <- Ash.Resource.Info.action(resource, name),
         true <- Enum.any?(arguments, &(&1.name == :task_id)),
         :ok <- supports_revision(arguments, expected) do
      params = %{task_id: task.id}

      params =
        if Enum.any?(arguments, &(&1.name == :expected_revision)) do
          Map.put(params, :expected_revision, revision)
        else
          params
        end

      resource
      |> Ash.ActionInput.for_action(name, params, options)
      |> Ash.run_action(options)
    else
      {:error, error} -> {:error, error}
      _invalid -> {:error, "task execution requires an authorized registered task command"}
    end
  end

  defp expected_revision(nil, _revision), do: :ok
  defp expected_revision(revision, revision), do: :ok

  defp expected_revision(_expected, _actual),
    do: {:error, "task revision changed; reload before running"}

  defp supports_revision(_arguments, nil), do: :ok

  defp supports_revision(arguments, _expected) do
    if Enum.any?(arguments, &(&1.name == :expected_revision)),
      do: :ok,
      else: {:error, "registered task command must enforce its expected revision"}
  end
end
