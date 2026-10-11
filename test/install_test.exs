# SPDX-FileCopyrightText: 2026 Vince Nibler
# SPDX-License-Identifier: MIT

defmodule Korero.InstallTest do
  use ExUnit.Case, async: false
  import Igniter.Test

  @app :korero_install_fixture
  @domain KoreroInstallFixture.Korero
  @argv [
    "--live-view",
    "KoreroInstallFixtureWeb.InboxLive",
    "--on-mount",
    "KoreroInstallFixtureWeb.LiveUserAuth:live_user_required",
    "--yes"
  ]

  test "generates native host resources, private routing and one codegen task without starting workers" do
    igniter = install(@argv)
    assert igniter.issues == []
    assert igniter.warnings == []

    for name <- ~w(task message channel inbox_folder inbox_preference inbox_item_state) do
      assert_creates(igniter, "lib/korero_install_fixture/korero/#{name}.ex")
    end

    assert Enum.map(igniter.tasks, &elem(&1, 0)) == ["ash.codegen"]
    assert_has_task(igniter, "ash.codegen", ["install_korero"])
    assert_unchanged(igniter, "lib/korero_install_fixture/application.ex")

    {:ok, config} = Rewrite.source(igniter.rewrite, "config/config.exs")
    assert Rewrite.Source.get(config, :content) =~ "TagAsh.Domain"
    assert Rewrite.Source.get(config, :content) =~ "KoreroInstallFixture.Repo"
  end

  test "applied reruns preserve generated resources and do not duplicate private routes" do
    first = install(@argv)

    second =
      first
      |> apply_igniter!()
      |> Map.put(:tasks, [])
      |> Igniter.compose_task("korero.install", @argv)

    assert second.issues == []
    assert second.warnings == []
    assert_unchanged(second)
    assert second.tasks == []
  end

  test "route configuration must name an existing live view and authenticated hook" do
    for argv <- [
          ["--live-view", "KoreroInstallFixtureWeb.InboxLive", "--yes"],
          [
            "--live-view",
            "KoreroInstallFixtureWeb.MissingLive",
            "--on-mount",
            "KoreroInstallFixtureWeb.LiveUserAuth:live_user_required",
            "--yes"
          ],
          [
            "--live-view",
            "KoreroInstallFixtureWeb.InboxLive",
            "--on-mount",
            "Missing.Hook:required",
            "--yes"
          ],
          ["--path", "https://example.invalid/inbox", "--yes"],
          ["--domain", "invalid.module", "--yes"]
        ] do
      igniter = install(argv)
      refute igniter.issues == []
      assert_unchanged(igniter)
      assert igniter.tasks == []
    end
  end

  test "resources-only installation reports that no client route has been installed" do
    install(["--yes"])
    |> assert_has_notice(&String.contains?(&1, "No Inbox route installed"))
    |> assert_unchanged("lib/korero_install_fixture_web/router.ex")
  end

  test "an existing AshAuthentication session with additional hooks and a scoped view is preserved" do
    files = fixture_files()

    router =
      String.replace(files["lib/korero_install_fixture_web/router.ex"], "# host routes", """
      scope "/", KoreroInstallFixtureWeb do
        ash_authentication_live_session :private_research,
          on_mount: [{KoreroInstallFixtureWeb.LiveUserAuth, :optional}, {KoreroInstallFixtureWeb.LiveUserAuth, :live_user_required}] do
          live "/inbox", InboxLive, :index
        end
      end
      """)

    igniter = install(@argv, Map.put(files, "lib/korero_install_fixture_web/router.ex", router))
    assert igniter.issues == []
    assert_unchanged(igniter, "lib/korero_install_fixture_web/router.ex")
  end

  test "a host can map task and message to its existing combined resource without parallel models" do
    files =
      Map.put(fixture_files(), "lib/korero_install_fixture/korero/item.ex", """
      defmodule KoreroInstallFixture.Korero.Item do
        def host_owned_contract, do: :preserved
      end
      """)

    argv = [
      "--task-resource",
      "KoreroInstallFixture.Korero.Item",
      "--message-resource",
      "KoreroInstallFixture.Korero.Item",
      "--yes"
    ]

    igniter = install(argv, files)
    assert igniter.issues == []
    assert_unchanged(igniter, "lib/korero_install_fixture/korero/item.ex")
    refute_creates(igniter, "lib/korero_install_fixture/korero/task.ex")
    refute_creates(igniter, "lib/korero_install_fixture/korero/message.ex")

    state =
      Rewrite.Source.get(
        Rewrite.source!(igniter.rewrite, "lib/korero_install_fixture/korero/inbox_item_state.ex"),
        :content
      )

    assert state =~ ~s("task" => KoreroInstallFixture.Korero.Item)
    assert state =~ ~s("message" => KoreroInstallFixture.Korero.Item)
  end

  test "host ownership and mutable customizations survive reruns" do
    installed = install(@argv) |> apply_igniter!() |> Map.put(:tasks, [])

    customized =
      Igniter.Project.Module.find_and_update_module!(
        installed,
        KoreroInstallFixture.Korero.Task,
        fn zipper ->
          {:ok,
           Igniter.Code.Common.add_code(zipper, "def customized_host_behavior, do: :preserved")}
        end
      )
      |> apply_igniter!()
      |> Map.put(:tasks, [])

    rerun = Igniter.compose_task(customized, "korero.install", @argv)
    assert rerun.issues == []
    assert_unchanged(rerun)
  end

  test "an existing unverified route is not silently claimed as private" do
    files = fixture_files()

    router =
      String.replace(
        files["lib/korero_install_fixture_web/router.ex"],
        "# host routes",
        "scope \"/\" do\n live \"/inbox\", KoreroInstallFixtureWeb.InboxLive, :index\nend"
      )

    igniter = install(@argv, Map.put(files, "lib/korero_install_fixture_web/router.ex", router))
    assert_has_issue(igniter, &String.contains?(&1, "unverified authentication contract"))
    assert_unchanged(igniter, "lib/korero_install_fixture_web/router.ex")
  end

  test "explicit namespaces and custom module choices are honored" do
    argv = [
      "--korero.domain",
      "KoreroInstallFixture.Work",
      "--korero.repo",
      "KoreroInstallFixture.Repo",
      "--korero.user-resource",
      "KoreroInstallFixture.Accounts.User",
      "--path",
      "/work",
      "--yes"
    ]

    igniter = install(argv)
    assert igniter.issues == []
    assert_creates(igniter, "lib/korero_install_fixture/work/task.ex")
    refute_creates(igniter, "lib/korero_install_fixture/korero/task.ex")
  end

  test "installed source compiles and acts through Ash with creator ownership and scoped channels" do
    igniter = install(["--yes"])
    assert igniter.issues == []
    compile_ets_fixture!(igniter)

    owner = %{id: Ash.UUID.generate()}
    stranger = %{id: Ash.UUID.generate()}
    task = Ash.create!(KoreroInstallFixture.Korero.Task, %{title: "Synthetic work"}, actor: owner)

    assert task.owner_id == owner.id
    assert {:ok, []} = Ash.read(KoreroInstallFixture.Korero.Task, actor: stranger)
    assert {:error, _} = Ash.update(task, %{}, action: :start, actor: stranger)
    assert {:error, _} = Ash.create(KoreroInstallFixture.Korero.Task, %{title: "Anonymous"})
    assert {:ok, %{status: :in_progress}} = Ash.update(task, %{}, action: :start, actor: owner)

    requested =
      Ash.create!(
        KoreroInstallFixture.Korero.Task,
        %{title: "Idempotent synthetic request", request_key: "synthetic:shared-request"},
        action: :request,
        actor: owner
      )

    assert {:error, _} =
             Ash.create(
               KoreroInstallFixture.Korero.Task,
               %{title: "Idempotent synthetic request", request_key: "synthetic:shared-request"},
               action: :request,
               actor: stranger
             )

    assert Ash.get!(KoreroInstallFixture.Korero.Task, requested.id, actor: owner).owner_id ==
             owner.id

    message =
      Ash.create!(
        KoreroInstallFixture.Korero.Message,
        %{title: "Read this", subject: "Synthetic article"},
        action: :compose,
        actor: owner
      )

    assert message.task_type == "message"
    assert message.owner_id == owner.id
    Ash.read!(KoreroInstallFixture.Korero.Message, actor: owner)

    assert Ash.get!(KoreroInstallFixture.Korero.Message, message.id, actor: owner).status ==
             :queued

    channel =
      Ash.create!(
        KoreroInstallFixture.Korero.Channel,
        %{key: "personal", kind: :email, label: "Synthetic channel"},
        action: :configure,
        actor: owner
      )

    assert channel.user_id == owner.id
    assert channel.app_key == "korero_install_fixture"
    assert {:ok, []} = Ash.read(KoreroInstallFixture.Korero.Channel, actor: stranger)

    assert {:error, _} =
             Ash.update(channel, %{label: "Foreign"},
               action: :update_configuration,
               actor: stranger
             )

    folder =
      Ash.create!(KoreroInstallFixture.Korero.InboxFolder, %{name: "Articles"}, actor: owner)

    foreign_folder =
      Ash.create!(KoreroInstallFixture.Korero.InboxFolder, %{name: "Private"}, actor: stranger)

    state =
      Ash.create!(
        KoreroInstallFixture.Korero.InboxItemState,
        %{source_kind: "task", source_id: task.id},
        action: :ensure_source,
        actor: owner
      )

    assert {:ok, %{folder_id: folder_id}} =
             Ash.update(state, %{folder_id: folder.id}, action: :file, actor: owner)

    assert folder_id == folder.id
    state = Ash.get!(KoreroInstallFixture.Korero.InboxItemState, state.id, actor: owner)

    assert {:error, _} =
             Ash.update(state, %{folder_id: foreign_folder.id}, action: :file, actor: owner)

    assert {:error, _} =
             Ash.create(
               KoreroInstallFixture.Korero.InboxItemState,
               %{source_kind: "task", source_id: task.id},
               action: :ensure_source,
               actor: stranger
             )
  end

  defp install(argv, files \\ fixture_files()) do
    test_project(app_name: @app, files: files)
    |> Igniter.compose_task("korero.install", argv)
  end

  defp fixture_files do
    %{
      "lib/korero_install_fixture/accounts/user.ex" => """
      defmodule KoreroInstallFixture.Accounts.User do
        use Ash.Resource, domain: KoreroInstallFixture.Accounts, data_layer: Ash.DataLayer.Ets
        ets do
          private? true
        end
        actions do
          defaults [:read, create: []]
        end
        attributes do
          uuid_primary_key :id
        end
      end
      """,
      "lib/korero_install_fixture/accounts.ex" => """
      defmodule KoreroInstallFixture.Accounts do
        use Ash.Domain, otp_app: :korero_install_fixture, validate_config_inclusion?: false
        resources do
          resource KoreroInstallFixture.Accounts.User
        end
      end
      """,
      "lib/korero_install_fixture/repo.ex" => """
      defmodule KoreroInstallFixture.Repo do
        use AshPostgres.Repo, otp_app: :korero_install_fixture
      end
      """,
      "lib/korero_install_fixture/application.ex" => """
      defmodule KoreroInstallFixture.Application do
        use Application
        def start(_type, _args), do: Supervisor.start_link([], strategy: :one_for_one)
      end
      """,
      "lib/korero_install_fixture_web/router.ex" => """
      defmodule KoreroInstallFixtureWeb.Router do
        use Phoenix.Router
        import Phoenix.LiveView.Router
        pipeline :browser do
          plug :fetch_session
        end
        # host routes
      end
      """,
      "lib/korero_install_fixture_web/inbox_live.ex" => """
      defmodule KoreroInstallFixtureWeb.InboxLive do
        use Phoenix.LiveView
      end
      """,
      "lib/korero_install_fixture_web/live_user_auth.ex" => """
      defmodule KoreroInstallFixtureWeb.LiveUserAuth do
        def on_mount(:live_user_required, _params, _session, socket), do: {:cont, socket}
      end
      """
    }
  end

  defp compile_ets_fixture!(igniter) do
    # Installer tests validate native resource actions without requiring a real
    # host database. Replace storage only, retaining the generated fragments,
    # owner relationships, policies, actions and source/folder authorization.
    Application.put_env(@app, :ash_domains, [@domain])

    resource_sources =
      for name <- ~w(task message channel inbox_folder inbox_preference inbox_item_state) do
        path = "lib/korero_install_fixture/korero/#{name}.ex"
        source = Rewrite.source!(igniter.rewrite, path)

        content =
          source
          |> Rewrite.Source.get(:content)
          |> String.replace(
            "data_layer: AshPostgres.DataLayer",
            "data_layer: Ash.DataLayer.Ets, extensions: [Korero.InstallFixtureIdentities]"
          )
          |> String.replace(
            ~r/  postgres do\n.*?\n  end\n/s,
            "  ets do\n    private? true\n  end\n"
          )

        content
      end

    domain_source =
      Rewrite.Source.get(
        Rewrite.source!(igniter.rewrite, "lib/korero_install_fixture/korero.ex"),
        :content
      )
      |> String.replace("use Ash.Domain,", "use Ash.Domain, validate_config_inclusion?: false,")

    quoted =
      [
        fixture_files()["lib/korero_install_fixture/accounts/user.ex"],
        fixture_files()["lib/korero_install_fixture/accounts.ex"]
        | resource_sources ++ [domain_source]
      ]
      |> Enum.map(&Code.string_to_quoted!/1)

    Code.compile_quoted({:__block__, [], quoted})
  end
end

defmodule Korero.InstallFixturePrecheck do
  @moduledoc false
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl) do
    {:ok,
     Enum.reduce(Ash.Resource.Info.identities(dsl), dsl, fn identity, acc ->
       Spark.Dsl.Transformer.replace_entity(
         acc,
         [:identities],
         %{identity | pre_check_with: KoreroInstallFixture.Korero},
         &(&1.name == identity.name)
       )
     end)}
  end
end

defmodule Korero.InstallFixtureIdentities do
  @moduledoc false
  use Spark.Dsl.Extension, transformers: [Korero.InstallFixturePrecheck]
end
