defmodule Korero.Message do
  @moduledoc """
  Reusable message-envelope fields and editing lifecycle for host-owned messages.

  The host owns message content, participants, delivery, authorization, storage,
  and transport policy. This fragment owns only the mutable communication
  envelope: an optional subject and stable opaque distribution keys. Adding
  distribution keys is idempotent and never removes existing recipients.
  """

  use Spark.Dsl.Fragment, of: Ash.Resource

  code_interface do
    define :edit_envelope
  end

  actions do
    update :edit_envelope do
      description "Edits the subject and idempotently adds distribution recipients"
      require_atomic? false
      accept []

      argument :subject, :string do
        allow_nil? true
        constraints allow_empty?: true
      end

      argument :add_distribution_keys, {:array, :string} do
        allow_nil? false
        default []
      end

      change &Korero.Message.prepare_edit/2
    end
  end

  attributes do
    attribute :subject, :string do
      allow_nil? true
      public? true
      constraints allow_empty?: true
    end

    attribute :distribution_keys, {:array, :string} do
      allow_nil? false
      default []
      public? true
      description "Opaque host-owned participant keys included in this message's distribution"
    end
  end

  @doc false
  def prepare_edit(changeset, _context) do
    changeset
    |> maybe_change_subject()
    |> add_distribution_keys()
  end

  defp maybe_change_subject(changeset) do
    case Ash.Changeset.get_argument(changeset, :subject) do
      nil -> changeset
      subject -> Ash.Changeset.force_change_attribute(changeset, :subject, String.trim(subject))
    end
  end

  defp add_distribution_keys(changeset) do
    existing = Ash.Changeset.get_data(changeset, :distribution_keys) || []
    additions = Ash.Changeset.get_argument(changeset, :add_distribution_keys) || []

    distribution_keys =
      (existing ++ additions)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
      |> Enum.sort()

    Ash.Changeset.force_change_attribute(changeset, :distribution_keys, distribution_keys)
  end
end
