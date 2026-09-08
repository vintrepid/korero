defmodule Inbox.ObanTest do
  use ExUnit.Case, async: true

  alias Inbox.Test.JobTask

  @operator %{role: :operator}

  test "a generated Oban worker executes the eligible native action with host authorization" do
    task =
      JobTask.create!(%{title: "Prepare a synthetic report", task_type: "machine_job"},
        actor: @operator
      )

    # An operator may request work, but this host reserves execution for its worker actor.
    assert {:error, %Ash.Error.Forbidden{}} = JobTask.start(task, %{}, actor: @operator)
    assert {:ok, %JobTask{status: :in_progress}} = perform_trigger(task)

    started = JobTask.by_id!(task.id, actor: @operator)
    assert started.status == :in_progress
    assert started.started_at
    assert started.revision == task.revision + 1
    assert is_nil(started.completed_at)

    assert {:cancel, :trigger_no_longer_applies} = perform_trigger(task)
    assert JobTask.by_id!(task.id, actor: @operator).revision == started.revision
  end

  test "the worker rechecks eligibility and leaves human and attached tasks unchanged" do
    human =
      JobTask.create!(%{title: "Review a synthetic report", task_type: "human_review"},
        actor: @operator
      )

    attached =
      JobTask.create!(
        %{
          title: "Review an attached record",
          task_type: "machine_job",
          target_resource: "report",
          target_key: "synthetic:one"
        },
        actor: @operator
      )

    for task <- [human, attached] do
      assert {:cancel, :trigger_no_longer_applies} = perform_trigger(task)
      unchanged = JobTask.by_id!(task.id, actor: @operator)
      assert unchanged.status == :queued
      assert unchanged.revision == task.revision
      assert is_nil(unchanged.started_at)
    end
  end

  defp perform_trigger(task) do
    changeset = AshOban.build_trigger(task, :start_machine)

    # Exercise the real generated worker via Oban's executor without a database.
    # Durable job insertion and transaction semantics belong to host integration tests.
    Inbox.Test.StartMachineWorker
    |> Oban.Testing.build_job(Ecto.Changeset.get_field(changeset, :args), [])
    |> Oban.Testing.perform_job([])
  end
end
