defmodule Korero.ClassificationTest do
  use ExUnit.Case, async: true
  alias Korero.Test.{Classification, OtherClassification, TagAssignment, TagContext}

  setup do
    reference = TagAsh.SubjectRef.build("article", Ash.UUID.generate())
    actor = %{id: Ash.UUID.generate(), subjects: [reference], tag_writer?: true}
    stranger = %{id: Ash.UUID.generate(), subjects: [reference], tag_writer?: true}
    %{actor: actor, stranger: stranger, reference: reference}
  end

  test "native TagAsh-shaped actions classify idempotently without completing source work", %{
    actor: actor,
    reference: reference
  } do
    first = classify!(Classification, actor, reference)
    retry = classify!(Classification, actor, reference)

    assert first == retry
    assert first.subject_ref == reference
    assert first.context_key == "topics"
    assert classifications!(Classification, actor, reference) == [first.tag]
    assert Ash.count!(TagAssignment, actor: actor) == 1
    assert_receive {:subject_authorized, actor_id, ^reference, nil, :classify}
    assert actor_id == actor.id
  end

  test "a tag context is independent for each application and user", %{
    actor: actor,
    stranger: stranger,
    reference: reference
  } do
    own = classify!(Classification, actor, reference)
    assert classifications!(Classification, stranger, reference) == []
    assert classifications!(OtherClassification, actor, reference) == []

    other_user = classify!(Classification, stranger, reference)
    other_app = classify!(OtherClassification, actor, reference)

    assert MapSet.size(MapSet.new([own.tag.id, other_user.tag.id, other_app.tag.id])) == 3
    assert classifications!(Classification, actor, reference) == [own.tag]
    assert classifications!(Classification, stranger, reference) == [other_user.tag]
    assert classifications!(OtherClassification, actor, reference) == [other_app.tag]
    assert Ash.count!(TagContext, actor: actor) == 3
  end

  test "classifying a message task leaves its requested work open", %{actor: actor} do
    task =
      Korero.Test.MessageTask.create!(
        %{title: "Send the invitation", task_type: "message"},
        authorize?: false
      )

    reference = TagAsh.SubjectRef.build("task", task.id)
    actor = %{actor | subjects: [reference]}
    classify!(Classification, actor, reference)
    persisted = Korero.Test.MessageTask.by_id!(task.id, authorize?: false)
    assert persisted.status == :queued
    assert persisted.completed_at == nil
  end

  test "source permission is rechecked before every read and mutation", %{
    actor: actor,
    reference: reference
  } do
    classify!(Classification, actor, reference)
    revoked = %{actor | subjects: []}

    assert {:error, _error} = classify(Classification, revoked, reference)
    assert {:error, _error} = classifications(Classification, revoked, reference)
    assert Ash.count!(TagAssignment, actor: actor) == 1
  end

  test "subject authorization receives the actual actor and host tenant", %{
    actor: actor,
    reference: reference
  } do
    assert {:ok, _classification} =
             Classification
             |> Ash.ActionInput.for_action(:classify, arguments(reference), tenant: "tenant-one")
             |> Ash.run_action(actor: actor)

    assert_receive {:subject_authorized, actor_id, ^reference, "tenant-one", :classify}
    assert actor_id == actor.id
  end

  test "unknown subjects and native backend policy failures do not create classification", %{
    actor: actor
  } do
    unknown = TagAsh.SubjectRef.build("article", "unknown")
    assert {:error, _error} = classify(Classification, actor, unknown)
    assert {:error, _error} = classify(Classification, actor, "Elixir.Arbitrary.Module")

    denied_backend = %{actor | tag_writer?: false}
    assert {:error, _error} = classify(Classification, denied_backend, hd(actor.subjects))
    assert Ash.count!(TagContext, actor: actor) == 0
    assert Ash.count!(TagAssignment, actor: actor) == 0
  end

  test "identity and tag IDs are not accepted as user-set classification inputs", %{
    actor: actor,
    stranger: stranger,
    reference: reference
  } do
    for forged <- [
          %{user_id: stranger.id},
          %{app_key: "other_app"},
          %{tag_id: Ash.UUID.generate()}
        ] do
      assert {:error, _error} =
               Classification
               |> Ash.ActionInput.for_action(:classify, Map.merge(arguments(reference), forged))
               |> Ash.run_action(actor: actor)
    end

    assert {:error, _error} = classify(Classification, nil, reference)
    assert Ash.count!(TagAssignment, actor: actor) == 0
  end

  defp arguments(reference),
    do: %{subject_ref: reference, tag_name: "Trip planning", tag_slug: "trip-planning"}

  defp classify(resource, actor, reference) do
    resource
    |> Ash.ActionInput.for_action(:classify, arguments(reference))
    |> Ash.run_action(actor: actor)
  end

  defp classify!(resource, actor, reference) do
    assert {:ok, result} = classify(resource, actor, reference)
    result
  end

  defp classifications(resource, actor, reference) do
    resource
    |> Ash.ActionInput.for_action(:classifications, %{subject_ref: reference})
    |> Ash.run_action(actor: actor)
  end

  defp classifications!(resource, actor, reference) do
    assert {:ok, result} = classifications(resource, actor, reference)
    result
  end
end
