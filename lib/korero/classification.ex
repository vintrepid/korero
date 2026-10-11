defmodule Korero.Classification do
  @moduledoc """
  Native Ash actions connecting authorized subjects to personal TagAsh contexts.

  Compose this fragment into a host-owned Ash resource. Implement
  `korero_app_key/0` and `korero_subject_authorizer/0` on that resource. The latter
  returns a trusted module implementing `Korero.Classification.SubjectAuthorizer`.
  Hosts provide action policies. No actor, context owner, tag ID, or executable
  module is accepted from the UI.

  The default backend is TagAsh's native resources/actions. A trusted host may
  return equivalent host-owned resources from `korero_tag_resources/0` as a map
  with `:context`, `:tag` and `:assignment` keys, for example to supply resource
  tenancy and authorization. Korero implements no tagging engine or hierarchy.
  Direct TagAsh access must be separately secured by the host; this facade is
  not a policy installed on TagAsh's underlying resources.
  """

  use Spark.Dsl.Fragment, of: Ash.Resource
  require Ash.Query

  @callback korero_subject_authorizer() :: module()
  @callback korero_tag_resources() :: %{context: module(), tag: module(), assignment: module()}
  @optional_callbacks korero_tag_resources: 0

  actions do
    action :classify, :map do
      argument :subject_ref, :string, allow_nil?: false

      argument :context_key, :string,
        allow_nil?: false,
        default: "topics",
        constraints: [allow_empty?: false, max_length: 100, trim?: true]

      argument :tag_name, :string,
        allow_nil?: false,
        constraints: [allow_empty?: false, trim?: true]

      argument :tag_slug, :string,
        allow_nil?: false,
        constraints: [allow_empty?: false, trim?: true]

      run &Korero.Classification.classify/2
    end

    action :classifications, {:array, :map} do
      argument :subject_ref, :string, allow_nil?: false

      argument :context_key, :string,
        allow_nil?: false,
        default: "topics",
        constraints: [allow_empty?: false, max_length: 100, trim?: true]

      run &Korero.Classification.classifications/2
    end
  end

  @doc false
  def classify(input, context) do
    with {:ok, scope, resources, options} <- authorized_scope(input, context, :classify),
         {:ok, tag_context} <-
           Ash.create(
             resources.context,
             %{
               owner_ref: Korero.Scope.reference(scope),
               key: input.arguments.context_key,
               name: input.arguments.context_key
             },
             Keyword.put(options, :action, :upsert)
           ),
         {:ok, tag} <-
           Ash.create(
             resources.tag,
             %{
               context_id: tag_context.id,
               name: input.arguments.tag_name,
               slug: input.arguments.tag_slug
             },
             Keyword.put(options, :action, :upsert)
           ),
         {:ok, assignment} <-
           Ash.create(
             resources.assignment,
             %{
               subject_ref: input.arguments.subject_ref,
               tag_id: tag.id,
               metadata: %{"origin" => "human", "app_key" => scope.app_key}
             },
             Keyword.put(options, :action, :attach)
           ) do
      {:ok,
       %{
         subject_ref: assignment.subject_ref,
         context_key: tag_context.key,
         tag: %{id: tag.id, name: tag.name, slug: tag.slug}
       }}
    end
  end

  @doc false
  def classifications(input, context) do
    with {:ok, scope, resources, options} <- authorized_scope(input, context, :read) do
      owner_ref = Korero.Scope.reference(scope)
      context_key = input.arguments.context_key

      resources.assignment
      |> Ash.Query.for_read(:for_subject, %{subject_ref: input.arguments.subject_ref})
      |> Ash.Query.filter(tag.context.owner_ref == ^owner_ref and tag.context.key == ^context_key)
      |> Ash.Query.load(:tag)
      |> Ash.read(options)
      |> case do
        {:ok, assignments} ->
          {:ok,
           Enum.map(assignments, fn assignment ->
             %{id: assignment.tag.id, name: assignment.tag.name, slug: assignment.tag.slug}
           end)}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp authorized_scope(input, context, operation) do
    with {:ok, scope} <- Korero.Scope.resolve(input.resource, context.actor),
         {:ok, _reference} <- TagAsh.SubjectRef.parse(input.arguments.subject_ref),
         true <- function_exported?(input.resource, :korero_subject_authorizer, 0),
         authorizer when is_atom(authorizer) <- input.resource.korero_subject_authorizer(),
         true <- Code.ensure_loaded?(authorizer),
         true <- function_exported?(authorizer, :authorize_subject, 2),
         :ok <-
           authorizer.authorize_subject(
             input.arguments.subject_ref,
             Map.merge(scope, %{operation: operation, tenant: context.tenant})
           ) do
      {:ok, scope, resources(input.resource),
       [actor: context.actor, tenant: context.tenant, authorize?: true]}
    else
      {:error, error} -> {:error, error}
      _invalid -> {:error, "classification requires a trusted authorized subject"}
    end
  end

  defp resources(resource) do
    if function_exported?(resource, :korero_tag_resources, 0) do
      resource.korero_tag_resources()
    else
      %{
        context: TagAsh.Resources.Context,
        tag: TagAsh.Resources.Tag,
        assignment: TagAsh.Resources.SubjectTag
      }
    end
  end
end
