defmodule Korero.MessageTaskTest do
  use ExUnit.Case, async: true
  alias Korero.Test.MessageTask

  test "a host composes a message as a task without coupling envelope edits to completion" do
    task =
      MessageTask.request!(
        %{title: "Share the article", task_type: "message", request_key: "message:one"},
        authorize?: false
      )

    addressed =
      MessageTask.edit_envelope!(
        task,
        %{subject: "An article to read", add_distribution_keys: ["person:one"]},
        authorize?: false
      )

    assert addressed.id == task.id
    assert addressed.task_type == "message"
    assert addressed.status == :queued
    assert addressed.completed_at == nil
    assert addressed.subject == "An article to read"
    assert addressed.distribution_keys == ["person:one"]
    assert MessageTask.by_id!(task.id, authorize?: false).status == :queued
  end
end
