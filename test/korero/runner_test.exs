defmodule Korero.RunnerTest do
  use ExUnit.Case, async: true
  alias Korero.Test.RunnerTask

  test "dispatch selects the trusted native command, preserves actor and does not complete work" do
    owner = %{id: Ash.UUID.generate()}

    task =
      RunnerTask.create!(%{title: "Invite a reader", task_type: "reading.article_invitation"},
        actor: owner
      )

    assert {:ok, %{task_id: id, actor_id: actor_id, revision: 1}} =
             run(task, owner, expected_revision: 1)

    assert id == task.id
    assert actor_id == owner.id
    assert RunnerTask.by_id!(task.id, actor: owner).status == :queued
  end

  test "foreign actors, absent actors, unknown versions and stale revisions fail closed" do
    owner = %{id: Ash.UUID.generate()}
    stranger = %{id: Ash.UUID.generate()}

    task =
      RunnerTask.create!(%{title: "Invite a reader", task_type: "reading.article_invitation"},
        actor: owner
      )

    assert {:error, _} = run(task, stranger)
    assert {:error, _} = run(task, nil)
    assert {:error, _} = run(task, owner, expected_revision: 2)

    unsupported =
      RunnerTask.create!(
        %{title: "Unknown", task_type: "reading.article_invitation", task_type_version: 99},
        actor: owner
      )

    assert {:error, _} = run(unsupported, owner)
    assert {:error, _} = run(task, owner, target_action: "complete")
  end

  defp run(task, actor, extra \\ []) do
    RunnerTask
    |> Ash.ActionInput.for_action(:run_task, Map.merge(%{task_id: task.id}, Map.new(extra)),
      actor: actor
    )
    |> Ash.run_action(actor: actor, authorize?: true)
  end
end
