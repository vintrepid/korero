defmodule Korero.Scope do
  @moduledoc """
  Trusted application identity and acting-user scope for Korero integrations.

  A host resource implements `korero_app_key/0`. This is a stable application
  key supplied by code, not a module name or a URL/form parameter. Every channel
  or classification operation derives the user from its Ash actor.
  """

  @callback korero_app_key() :: String.t()

  @spec resolve(module(), term()) :: {:ok, map()} | {:error, String.t()}
  def resolve(resource, %{id: user_id} = actor) when is_binary(user_id) do
    with {:ok, id} <- Ash.Type.cast_input(:uuid, user_id),
         true <- function_exported?(resource, :korero_app_key, 0),
         app_key when is_binary(app_key) <- resource.korero_app_key(),
         true <- Regex.match?(~r/^[a-z][a-z0-9_-]*$/, app_key) do
      {:ok, %{app_key: app_key, user_id: id, actor: actor}}
    else
      _invalid ->
        {:error, "Korero requires an authenticated UUID actor and trusted application key"}
    end
  end

  def resolve(_resource, _actor), do: {:error, "Korero requires an authenticated UUID actor"}

  @doc false
  def own(changeset, context) do
    case resolve(changeset.resource, context.actor) do
      {:ok, scope} ->
        if changeset.action_type == :create do
          changeset
          |> Ash.Changeset.force_change_attribute(:user_id, scope.user_id)
          |> Ash.Changeset.force_change_attribute(:app_key, scope.app_key)
        else
          guard_channel_update(changeset, scope, context)
        end

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  @doc false
  def validate_channel_scope(changeset, _context) do
    context = %{actor: get_in(changeset.context, [:private, :actor]), tenant: changeset.tenant}

    case resolve(changeset.resource, context.actor) do
      {:ok, scope} ->
        if changeset.action_type == :create do
          if Ash.Changeset.get_attribute(changeset, :user_id) == scope.user_id and
               Ash.Changeset.get_attribute(changeset, :app_key) == scope.app_key,
             do: changeset,
             else:
               Ash.Changeset.add_error(
                 changeset,
                 "channel configuration belongs to another scope"
               )
        else
          guard_channel_update(changeset, scope, context)
        end

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  defp guard_channel_update(changeset, scope, context) do
    options = [actor: context.actor, tenant: context.tenant, authorize?: true]
    immutable = [:id, :user_id, :app_key, :key]

    case Ash.get(changeset.resource, changeset.data.id, options) do
      {:ok, %{user_id: user_id, app_key: app_key} = persisted}
      when user_id == scope.user_id and app_key == scope.app_key ->
        expected = Map.take(persisted, immutable)
        proposed = Map.new(immutable, &{&1, Ash.Changeset.get_attribute(changeset, &1)})

        if Map.take(changeset.data, immutable) == expected and proposed == expected,
          do: changeset,
          else:
            Ash.Changeset.add_error(
              changeset,
              "channel scope differs from its persisted configuration"
            )

      _forbidden ->
        Ash.Changeset.add_error(changeset, "channel configuration belongs to another scope")
    end
  end

  @doc false
  def for_actor(query, context) do
    case resolve(query.resource, context.actor) do
      {:ok, scope} ->
        Ash.Query.filter_input(query, %{user_id: scope.user_id, app_key: scope.app_key})

      {:error, error} ->
        Ash.Query.add_error(query, error)
    end
  end

  @doc "Opaque TagAsh owner reference distinguishing each application and person."
  def reference(%{app_key: app_key, user_id: user_id}) do
    TagAsh.SubjectRef.build("korero_scope", app_key <> ":" <> user_id)
  end
end
