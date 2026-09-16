defmodule Korero.MessageTest do
  use ExUnit.Case, async: true

  alias Korero.Test.Message

  test "edits a subject and idempotently adds opaque distribution keys" do
    message =
      Message
      |> Ash.Changeset.for_create(:create, %{
        content: "The report is ready",
        subject: "Original subject",
        distribution_keys: ["user:one"]
      })
      |> Ash.create!(authorize?: false)

    edited =
      Message.edit_envelope!(
        message,
        %{subject: "  Updated subject  ", add_distribution_keys: ["user:two", "user:one"]},
        authorize?: false
      )

    assert edited.subject == "Updated subject"
    assert edited.distribution_keys == ["user:one", "user:two"]

    retried =
      Message.edit_envelope!(
        edited,
        %{add_distribution_keys: ["user:two"]},
        authorize?: false
      )

    assert retried.subject == "Updated subject"
    assert retried.distribution_keys == ["user:one", "user:two"]
  end

  test "an empty subject is an intentional edit while nil leaves it unchanged" do
    message =
      Message
      |> Ash.Changeset.for_create(:create, %{content: "Body", subject: "Keep me"})
      |> Ash.create!(authorize?: false)

    unchanged =
      Message.edit_envelope!(message, %{subject: nil}, authorize?: false)

    assert unchanged.subject == "Keep me"

    cleared =
      Message.edit_envelope!(unchanged, %{subject: "  "}, authorize?: false)

    assert cleared.subject == ""
  end
end
