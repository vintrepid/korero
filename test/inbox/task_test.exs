defmodule Inbox.TaskTest do
  use ExUnit.Case, async: true

  alias Inbox.Test.Task

  describe "standalone workflow" do
    test "a generic task needs no target and may be completed directly" do
      task = create_task!(%{title: "Review the request", priority: 3})

      assert task.task_type == "generic"
      assert task.task_type_version == 1
      assert task.target_resource == nil
      assert task.target_key == nil

      completed =
        Task.complete!(task, %{completed_by_key: "user:one"}, authorize?: false)

      assert completed.status == :completed
      assert %DateTime{} = completed.started_at
      assert completed.completed_at == completed.started_at
      assert completed.completed_by_key == "user:one"
      assert completed.priority == nil
      assert completed.next_action_at == nil
    end

    test "assignment does not imply that work started" do
      task = create_task!(%{title: "Prepare reports"})

      assigned = Task.assign!(task, %{assignee_key: "worker:one"}, authorize?: false)

      assert assigned.assignee_key == "worker:one"
      assert assigned.status == :queued
      assert assigned.started_at == nil

      started = Task.start!(assigned, %{}, authorize?: false)

      assert started.status == :in_progress
      assert %DateTime{} = started.started_at

      completed = Task.complete!(started, %{}, authorize?: false)

      assert completed.status == :completed
      assert DateTime.compare(completed.completed_at, completed.started_at) in [:eq, :gt]
    end

    test "lifecycle timestamps are server-owned inputs" do
      task = create_task!(%{title: "Use the real clock"})

      assert {:error, error} =
               Task.start(task, %{at: ~U[2099-01-01 00:00:00Z]}, authorize?: false)

      assert Exception.message(error) =~ "at"
      assert Task.by_id!(task.id, authorize?: false).status == :queued
    end

    test "an optional resource and its opaque key must be supplied together" do
      assert {:error, target_error} =
               Task.create(
                 %{title: "Broken attachment", target_resource: "record"},
                 authorize?: false
               )

      assert Exception.message(target_error) =~ "must be provided together with target_key"

      assert {:error, source_error} =
               Task.create(
                 %{title: "Broken source", request_source_key: "message:one"},
                 authorize?: false
               )

      assert Exception.message(source_error) =~
               "must be provided together with request_source_key"

      task =
        create_task!(%{
          title: "Attached",
          request_source_resource: "message",
          request_source_key: "message:one",
          target_resource: "record",
          target_key: "record:one"
        })

      assert task.request_source_key == "message:one"
      assert task.target_key == "record:one"
    end

    test "attached work cannot bypass its typed target dispatcher" do
      task =
        create_task!(%{
          title: "Review the record",
          target_resource: "record",
          target_key: "record:one"
        })

      assert {:error, error} =
               Task.complete(task, %{completed_by_key: "user:one"}, authorize?: false)

      assert Exception.message(error) =~ "attached tasks require the typed target dispatcher"

      persisted = Task.by_id!(task.id, authorize?: false)
      assert persisted.status == :queued
      assert persisted.started_at == nil
      assert persisted.completed_at == nil
    end

    test "cancellation is terminal without pretending the task completed" do
      task =
        create_task!(%{
          title: "Obsolete task",
          priority: 5,
          next_action_at: DateTime.add(DateTime.utc_now(), 3_600)
        })

      cancelled =
        Task.cancel!(task, %{cancelled_by_key: "user:one"}, authorize?: false)

      assert cancelled.status == :cancelled
      assert %DateTime{} = cancelled.cancelled_at
      assert cancelled.completed_at == nil
      assert cancelled.priority == nil
      assert cancelled.next_action_at == nil
    end

    test "terminal tasks cannot transition back into the open queue" do
      completed =
        %{title: "Stay completed"}
        |> create_task!()
        |> Task.complete!(%{}, authorize?: false)

      cancelled =
        %{title: "Stay cancelled"}
        |> create_task!()
        |> Task.cancel!(%{}, authorize?: false)

      for task <- [completed, cancelled] do
        assert {:error, _error} = Task.start(task, %{}, authorize?: false)
        assert {:error, _error} = Task.block(task, %{}, authorize?: false)

        assert {:error, _error} =
                 Task.defer(
                   task,
                   %{next_action_at: DateTime.add(DateTime.utc_now(), 3_600)},
                   authorize?: false
                 )

        assert Task.by_id!(task.id, authorize?: false).status == task.status
      end
    end

    test "optimistic revision rejects an update made from a stale record" do
      task = create_task!(%{title: "Only one writer"})
      stale = Task.by_id!(task.id, authorize?: false)

      updated = Task.assign!(task, %{assignee_key: "worker:one"}, authorize?: false)

      assert updated.revision == task.revision + 1

      assert {:error, error} =
               Task.prioritize(stale, %{priority: 9}, authorize?: false)

      assert Exception.message(error) =~ "stale"
      assert Task.by_id!(task.id, authorize?: false).priority == task.priority
    end
  end

  describe "idempotent requests" do
    test "missing request lookups are optional and retry helpers report absence" do
      assert {:ok, nil} = Task.by_request_key("request:missing", authorize?: false)

      assert {:error, :task_not_found} =
               Inbox.Task.complete_by_request_key(Task, "request:missing", %{}, authorize?: false)

      assert {:error, :task_not_found} =
               Inbox.Task.cancel_by_request_key(Task, "request:missing", %{}, authorize?: false)
    end

    test "request is the only creation path that accepts a request key" do
      assert {:error, error} =
               Task.create(
                 %{title: "Wrong creation path", request_key: "request:wrong-path"},
                 authorize?: false
               )

      assert Exception.message(error) =~ "request_key"

      task =
        Task.request!(
          %{title: "Correct creation path", request_key: "request:right-path"},
          authorize?: false
        )

      assert task.request_key == "request:right-path"
    end

    test "a request key identifies one stable task occurrence" do
      attributes = %{
        request_key: "record-review:request:one",
        task_type: "record_review",
        title: "Review the record",
        target_resource: "record",
        target_key: "record:one",
        priority: 1
      }

      first = Task.request!(attributes, authorize?: false)
      repeated = Task.request!(%{attributes | priority: 99}, authorize?: false)

      assert repeated.id == first.id
      assert repeated.priority == first.priority
      assert repeated.revision == first.revision
    end

    test "a request key cannot be reused for a different target" do
      attributes = %{
        request_key: "record-review:request:two",
        task_type: "record_review",
        title: "Review the record",
        target_resource: "record",
        target_key: "record:two"
      }

      Task.request!(attributes, authorize?: false)

      assert {:error, error} =
               Task.request(%{attributes | target_key: "record:different"}, authorize?: false)

      assert Exception.message(error) =~ "already identifies a different task"
    end

    test "completion and cancellation retries return the terminal task unchanged" do
      complete_request = %{
        request_key: "standalone:complete",
        title: "Complete once",
        priority: 2
      }

      complete_task = Task.request!(complete_request, authorize?: false)

      assert {:ok, completed} =
               Inbox.Task.complete_by_request_key(
                 Task,
                 complete_task.request_key,
                 %{completed_by_key: "user:one"},
                 authorize?: false
               )

      assert {:ok, completed_retry} =
               Inbox.Task.complete_by_request_key(
                 Task,
                 complete_task.request_key,
                 %{completed_by_key: "user:two"},
                 authorize?: false
               )

      assert completed_retry.id == completed.id
      assert completed_retry.revision == completed.revision
      assert completed_retry.completed_at == completed.completed_at
      assert completed_retry.completed_by_key == "user:one"

      cancel_task =
        Task.request!(
          %{request_key: "standalone:cancel", title: "Cancel once", priority: 4},
          authorize?: false
        )

      assert {:ok, cancelled} =
               Inbox.Task.cancel_by_request_key(
                 Task,
                 cancel_task.request_key,
                 %{cancelled_by_key: "user:one"},
                 authorize?: false
               )

      assert {:ok, cancelled_retry} =
               Inbox.Task.cancel_by_request_key(
                 Task,
                 cancel_task.request_key,
                 %{cancelled_by_key: "user:two"},
                 authorize?: false
               )

      assert cancelled_retry.id == cancelled.id
      assert cancelled_retry.revision == cancelled.revision
      assert cancelled_retry.cancelled_at == cancelled.cancelled_at
      assert cancelled_retry.cancelled_by_key == "user:one"
    end
  end

  test "the open queue excludes terminal work and orders priority with nulls last" do
    later = create_task!(%{title: "Later priority", priority: 5})
    first = create_task!(%{title: "First priority", priority: 1})
    unspecified = create_task!(%{title: "No priority", priority: nil})

    %{title: "Completed work"}
    |> create_task!()
    |> Task.complete!(%{}, authorize?: false)

    assert Enum.map(Task.open!(authorize?: false), & &1.id) ==
             [first.id, later.id, unspecified.id]
  end

  test "host authorization governs both native actions and terminal retry helpers" do
    alias Inbox.Test.ProtectedTask

    attributes = %{request_key: "protected:one", title: "Protected work"}
    actor = %{role: :operator}

    assert {:error, %Ash.Error.Forbidden{}} =
             ProtectedTask.request(attributes, actor: %{role: :visitor}, authorize?: true)

    task = ProtectedTask.request!(attributes, actor: actor, authorize?: true)

    assert {:error, %Ash.Error.Forbidden{}} =
             Inbox.Task.complete_by_request_key(ProtectedTask, task.request_key, %{},
               actor: %{role: :visitor},
               authorize?: true
             )

    assert ProtectedTask.by_id!(task.id, actor: actor, authorize?: true).status == :queued

    assert {:ok, %{status: :completed}} =
             Inbox.Task.complete_by_request_key(ProtectedTask, task.request_key, %{},
               actor: actor,
               authorize?: true
             )
  end

  defp create_task!(attributes) do
    Task.create!(Map.put_new(attributes, :priority, 1), authorize?: false)
  end
end
