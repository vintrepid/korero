defmodule Korero.ChannelTest do
  use ExUnit.Case, async: true
  alias Korero.Test.Channel

  setup do
    %{owner: %{id: Ash.UUID.generate()}, stranger: %{id: Ash.UUID.generate()}}
  end

  test "the same channel key belongs independently to each person's application scope", %{
    owner: owner,
    stranger: stranger
  } do
    own = configure!(owner)
    other = configure!(stranger)

    assert own.id != other.id
    assert own.app_key == "example"
    assert own.user_id == owner.id
    assert Enum.map(Ash.read!(Channel, actor: owner), & &1.id) == [own.id]
    assert Enum.map(Ash.read!(Channel, actor: stranger), & &1.id) == [other.id]
    assert {:error, _error} = Ash.read(Channel)
  end

  test "configuration retries are idempotent and changes retain scope", %{owner: owner} do
    first = configure!(owner)
    retry = configure!(owner, %{label: "My work email"})
    assert retry.id == first.id
    assert retry.label == first.label

    changed =
      Ash.update!(retry, %{enabled: false}, action: :update_configuration, actor: owner)

    assert changed.app_key == retry.app_key
    assert changed.user_id == owner.id
    refute changed.enabled
    assert changed.revision == retry.revision + 1

    assert {:error, _error} =
             Ash.update(retry, %{label: "Stale edit"},
               action: :update_configuration,
               actor: owner
             )
  end

  test "foreign users cannot alter a channel or spoof owner/application configuration", %{
    owner: owner,
    stranger: stranger
  } do
    own = configure!(owner)

    assert {:error, _error} =
             Ash.update(own, %{credential_ref: "secrets:other"},
               action: :update_configuration,
               actor: stranger
             )

    assert {:error, _error} =
             Ash.update(%{own | app_key: "other_app"}, %{label: "Wrong application"},
               action: :update_configuration,
               actor: owner
             )

    for forged <- [%{user_id: stranger.id}, %{app_key: "other_app"}] do
      assert {:error, _error} =
               Ash.create(Channel, Map.merge(attributes(), forged),
                 action: :configure,
                 actor: owner
               )
    end

    assert {:error, _error} =
             Ash.create(Channel, Map.put(attributes(), :password, "not-a-reference"),
               action: :configure,
               actor: owner
             )

    assert Ash.get!(Channel, own.id, actor: owner).credential_ref == "secrets:personal-email"
  end

  test "scope guards stay active even if a caller disables host policies", %{
    owner: owner,
    stranger: stranger
  } do
    own = configure!(owner)

    assert Ash.read!(Channel, actor: stranger, authorize?: false) == []

    assert {:error, _error} =
             Ash.update(own, %{label: "Not my email"},
               action: :update_configuration,
               actor: stranger,
               authorize?: false
             )

    assert {:error, _error} =
             Ash.create(Channel, attributes(), action: :configure, authorize?: false)
  end

  test "a forged in-memory record cannot transfer another person's configuration", %{
    owner: owner,
    stranger: stranger
  } do
    own = configure!(owner)
    forged = %{own | user_id: stranger.id}

    assert {:error, _} =
             Ash.update(forged, %{label: "Forged transfer"},
               action: :update_configuration,
               actor: stranger,
               authorize?: false
             )

    assert {:error, _} =
             Ash.update(%{own | key: "another_key"}, %{label: "Forged key"},
               action: :update_configuration,
               actor: owner
             )

    assert Ash.get!(Channel, own.id, actor: owner).user_id == owner.id
    assert Ash.get!(Channel, own.id, actor: owner).label == own.label
  end

  test "immutable scope cannot be changed after constructing an authorized changeset", %{
    owner: owner,
    stranger: stranger
  } do
    own = configure!(owner)

    for authorize? <- [true, false],
        {attribute, forged} <- [
          id: Ash.UUID.generate(),
          user_id: stranger.id,
          app_key: "other_app",
          key: "another_key"
        ] do
      changeset =
        own
        |> Ash.Changeset.for_update(:update_configuration, %{label: "Forged scope"}, actor: owner)
        |> Ash.Changeset.force_change_attribute(attribute, forged)

      assert {:error, _} = Ash.update(changeset, actor: owner, authorize?: authorize?)
    end

    persisted = Ash.get!(Channel, own.id, actor: owner)

    assert Map.take(persisted, [:id, :user_id, :app_key, :key, :label, :revision]) ==
             Map.take(own, [:id, :user_id, :app_key, :key, :label, :revision])
  end

  test "creation cannot force another scope after deriving actor ownership", %{
    owner: owner,
    stranger: stranger
  } do
    for {attribute, forged} <- [user_id: stranger.id, app_key: "other_app"] do
      changeset =
        Channel
        |> Ash.Changeset.for_create(:configure, attributes(), actor: owner)
        |> Ash.Changeset.force_change_attribute(attribute, forged)

      assert {:error, _} = Ash.create(changeset, actor: owner, authorize?: false)
    end

    assert Ash.read!(Channel, actor: owner) == []
    assert Ash.read!(Channel, actor: stranger) == []
  end

  test "scope validation uses the execution actor rather than the changeset construction actor",
       %{
         owner: owner,
         stranger: stranger
       } do
    own = configure!(owner)

    changeset =
      Ash.Changeset.for_update(own, :update_configuration, %{label: "Changed actor"},
        actor: owner
      )

    assert {:error, _} = Ash.update(changeset, actor: stranger, authorize?: false)

    create =
      Ash.Changeset.for_create(Channel, :configure, Map.put(attributes(), :key, "new_key"),
        actor: owner
      )

    assert {:error, _} = Ash.create(create, actor: stranger, authorize?: false)
    assert Ash.get!(Channel, own.id, actor: owner).label == own.label
    assert Ash.read!(Channel, actor: stranger) == []
  end

  defp configure!(actor, changes \\ %{}),
    do: Ash.create!(Channel, Map.merge(attributes(), changes), action: :configure, actor: actor)

  defp attributes do
    %{
      key: "personal_email",
      kind: :email,
      label: "Personal email",
      address: "person@example.test",
      provider_key: "personal_provider",
      credential_ref: "secrets:personal-email"
    }
  end
end
