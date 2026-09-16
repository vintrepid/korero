defmodule Korero.FilingTest do
  use ExUnit.Case, async: true

  alias Korero.Test.{InboxFolder, InboxItemState, InboxPreference}

  setup do
    %{owner: %{id: Ash.UUID.generate()}, stranger: %{id: Ash.UUID.generate()}}
  end

  test "stars, archive, and Trash are separate personal states", %{owner: owner} do
    item = item!(owner)
    starred = change!(item, :star, owner)
    archived = change!(starred, :archive, owner)
    trashed = change!(archived, :trash, owner)
    trashed_again = change!(trashed, :trash, owner)

    assert archived.starred
    assert archived.visibility == :archived
    assert trashed.visibility == :trashed
    assert trashed_again.trashed_at == trashed.trashed_at

    restored = change!(trashed_again, :restore, owner)
    assert restored.visibility == :active
    assert restored.trashed_at == nil
    assert restored.starred
  end

  test "emptying retains the row and cannot be undone by normal restore", %{owner: owner} do
    trashed = owner |> item!() |> change!(:trash, owner)
    emptied = change!(trashed, :empty, owner)
    repeated = change!(emptied, :empty, owner)

    assert repeated.id == trashed.id
    assert repeated.visibility == :purged
    assert repeated.emptied_at == emptied.emptied_at
    assert Ash.get!(InboxItemState, emptied.id, actor: owner).visibility == :purged
    assert {:error, _error} = change(emptied, :restore, owner)
    assert {:error, _error} = change(emptied, :trash, owner)
    assert {:error, _error} = change(emptied, :star, owner)
  end

  test "ensuring a source is idempotent and never resurrects emptied state", %{owner: owner} do
    item = item!(owner)
    emptied = item |> change!(:trash, owner) |> change!(:empty, owner)
    repeated = item!(owner)
    assert repeated.id == emptied.id
    assert repeated.visibility == :purged
    assert repeated.emptied_at == emptied.emptied_at
  end

  test "a stale empty operation cannot discard an item restored concurrently", %{owner: owner} do
    trashed = owner |> item!() |> change!(:trash, owner)
    restored = change!(trashed, :restore, owner)
    assert {:error, _error} = change(trashed, :empty, owner)
    assert Ash.get!(InboxItemState, restored.id, actor: owner).visibility == :active
  end

  test "owner identity is not a caller-set input and access stays personal", %{
    owner: owner,
    stranger: stranger
  } do
    item = item!(owner)
    assert Ash.read!(InboxItemState, actor: stranger) == []
    assert {:error, _error} = change(item, :trash, stranger)
    assert {:error, _error} = change(item, :star, nil)

    assert {:error, _error} =
             Ash.create(
               InboxItemState,
               %{source_kind: "message", source_id: "other", user_id: stranger.id},
               action: :ensure_source,
               actor: owner
             )

    own_copy = item!(stranger)
    assert own_copy.id != item.id
  end

  test "folder names and retention belong to their owner", %{owner: owner, stranger: stranger} do
    folder = Ash.create!(InboxFolder, %{name: "  Family  "}, actor: owner)
    assert to_string(folder.name) == "Family"
    assert Ash.read!(InboxFolder, actor: stranger) == []

    assert {:error, _error} =
             Ash.update(folder, %{name: "Other"}, action: :rename, actor: stranger)

    preference = Ash.create!(InboxPreference, %{}, action: :configure, actor: owner)
    assert preference.trash_retention_days == 30

    never =
      Ash.create!(InboxPreference, %{trash_retention_days: nil}, action: :configure, actor: owner)

    assert never.id == preference.id
    assert never.trash_retention_days == nil
    assert Ash.read!(InboxPreference, actor: stranger) == []

    assert {:error, _error} =
             Ash.create(InboxPreference, %{trash_retention_days: -1},
               action: :configure,
               actor: owner
             )

    assert {:error, _error} =
             Ash.create(InboxPreference, %{trash_retention_days: 36_501},
               action: :configure,
               actor: owner
             )
  end

  test "retention includes the exact elapsed-days boundary and nil keeps indefinitely" do
    now = ~U[2026-09-09 12:00:00.000000Z]
    boundary = DateTime.add(now, -30 * 86_400)
    assert Korero.Filing.expired?(boundary, 30, now)
    refute Korero.Filing.expired?(DateTime.add(boundary, 1, :microsecond), 30, now)
    refute Korero.Filing.expired?(boundary, nil, now)
    assert Korero.Filing.expired?(now, 0, now)
    refute Korero.Filing.expired?(DateTime.add(now, 1), 0, now)
  end

  test "Trash and emptied items do not leak into other smart folders" do
    item = %{
      visibility: :active,
      queued?: true,
      sent?: true,
      starred?: true,
      scheduled?: true,
      draft?: true,
      project_key: "app:example",
      folder_id: Ash.UUID.generate()
    }

    assert "inbox" in Korero.Filing.folder_keys(item)
    assert "scheduled" in Korero.Filing.folder_keys(item)
    archived = Korero.Filing.folder_keys(%{item | visibility: :archived})
    assert "archive" in archived
    assert "starred" in archived
    assert "sent" in archived
    refute "inbox" in archived
    refute "scheduled" in archived
    refute "drafts" in archived
    assert Korero.Filing.folder_keys(%{item | visibility: :trashed}) == ["trash"]
    assert Korero.Filing.folder_keys(%{item | visibility: :purged}) == []
  end

  defp item!(actor) do
    Ash.create!(InboxItemState, %{source_kind: "message", source_id: "one"},
      action: :ensure_source,
      actor: actor
    )
  end

  defp change!(record, action, actor), do: Ash.update!(record, %{}, action: action, actor: actor)
  defp change(record, action, actor), do: Ash.update(record, %{}, action: action, actor: actor)
end
