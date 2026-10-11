# SPDX-FileCopyrightText: 2026 Vince Nibler
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Korero.Install do
    @shortdoc "Install host-owned Korero resources and an explicitly authenticated Inbox route"
    @moduledoc """
    Generate host-owned resources using Korero's native fragments, register their
    Ash domain and TagAsh repository, and schedule Ash-generated migrations.

    The default user, repo, domain and router are Host.Accounts.User, Host.Repo,
    Host.Korero and HostWeb.Router. Override them with `--user-resource`, `--repo`,
    `--domain`, and `--router`.

    Routing is opt-in: `--live-view HostWeb.InboxLive` must name an existing
    client module, and `--on-mount HostWeb.LiveUserAuth:live_user_required` must
    name an existing host authentication hook. `--path` defaults to `/inbox`.
    No placeholder client is created, and no unauthenticated route is guessed.

    Existing resources are preserved, not overwritten. The generated resources
    are private to their actor. Messages are tasks with a communication envelope;
    this does not configure an email provider or grant recipients any access.
    Channel credentials and transport policy remain application/user-owned.
    No database is migrated, Oban supervisor started, queue configured, worker
    scheduled, business action dispatched, or message sent by this task.
    """

    use Igniter.Mix.Task

    @impl true
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        group: :korero,
        schema: [
          user_resource: :string,
          repo: :string,
          domain: :string,
          router: :string,
          path: :string,
          live_view: :string,
          on_mount: :string
        ],
        defaults: [path: "/inbox"]
      }
    end

    @impl true
    def igniter(igniter) do
      {igniter, options} = options(igniter)

      if igniter.issues == [] do
        original_sources = sources(igniter)

        igniter
        |> install_resources(options)
        |> configure(options)
        |> install_route(options)
        |> then(fn updated ->
          if updated.issues == [] && changed_since?(updated, original_sources) do
            Ash.Igniter.codegen(updated, "install_korero")
          else
            updated
          end
        end)
      else
        igniter
      end
    end

    defp options(igniter) do
      app = Igniter.Project.Application.app_name(igniter)
      argv = igniter.args.options

      {igniter, user} = module_option(igniter, argv[:user_resource], "Accounts.User")
      {igniter, repo} = module_option(igniter, argv[:repo], "Repo")
      {igniter, domain} = module_option(igniter, argv[:domain], "Korero")

      router_default = inspect(Igniter.Project.Module.module_name(igniter, "Web.Router"))
      router_default = String.replace_suffix(router_default, ".Web.Router", "Web.Router")
      {igniter, router} = module_option(igniter, argv[:router] || router_default, nil)
      {igniter, live_view} = module_option(igniter, argv[:live_view], nil)
      {igniter, hook} = auth_hook(igniter, argv[:on_mount])

      igniter =
        igniter
        |> require_module(user, "User resource")
        |> require_module(repo, "Repository")

      igniter =
        if live_view do
          igniter
          |> require_module(router, "Router")
          |> require_module(live_view, "Inbox LiveView")
          |> require_module(hook && hook.module, "Authentication on_mount hook")
        else
          igniter
        end

      path = argv[:path]

      igniter =
        if is_binary(path) && Regex.match?(~r{^/(?:[a-zA-Z0-9_-]+/?)*$}, path) do
          igniter
        else
          Igniter.add_issue(igniter, "--path must be a local literal path such as /inbox.")
        end

      {igniter,
       %{
         app: app,
         app_key: Atom.to_string(app),
         user: user,
         repo: repo,
         domain: domain,
         router: router,
         live_view: live_view,
         hook: hook,
         path: path
       }}
    end

    defp module_option(igniter, nil, nil), do: {igniter, nil}

    defp module_option(igniter, nil, suffix),
      do: {igniter, Igniter.Project.Module.module_name(igniter, suffix)}

    defp module_option(igniter, value, _suffix) do
      if Regex.match?(~r/^[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*$/, value) do
        {igniter, Igniter.Project.Module.parse(value)}
      else
        {Igniter.add_issue(igniter, "Invalid module option #{inspect(value)}."), nil}
      end
    end

    defp auth_hook(igniter, nil), do: {igniter, nil}

    defp auth_hook(igniter, value) do
      case Regex.run(~r/^([A-Z][A-Za-z0-9_.]*):([a-z][a-zA-Z0-9_]*)$/, value) do
        [_, module, argument] ->
          {igniter, module} = module_option(igniter, module, nil)
          {igniter, %{module: module, argument: argument}}

        _invalid ->
          {Igniter.add_issue(igniter, "--on-mount must be Existing.HostAuth:hook_argument."), nil}
      end
    end

    defp require_module(igniter, nil, label),
      do:
        Igniter.add_issue(igniter, "#{label} must be explicitly configured before installation.")

    defp require_module(igniter, module, label) do
      case Igniter.Project.Module.module_exists(igniter, module) do
        {true, igniter} ->
          igniter

        {false, igniter} ->
          Igniter.add_issue(igniter, "#{label} #{inspect(module)} does not exist.")
      end
    end

    defp install_resources(igniter, options) do
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, options.domain)

      igniter =
        if exists? do
          igniter
        else
          Igniter.Project.Module.create_module(igniter, options.domain, """
          use Ash.Domain, otp_app: #{inspect(options.app)}
          """)
        end

      resources = [
        {"Task", task_body(options, false)},
        {"Message", task_body(options, true)},
        {"Channel", channel_body(options)},
        {"InboxFolder", filing_body(options, "InboxFolder")},
        {"InboxPreference", filing_body(options, "InboxPreference")},
        {"InboxItemState", filing_body(options, "InboxItemState")}
      ]

      Enum.reduce(resources, igniter, fn {name, body}, acc ->
        module = Module.concat(options.domain, name)
        {exists?, acc} = Igniter.Project.Module.module_exists(acc, module)

        acc =
          if exists? do
            Igniter.add_notice(
              acc,
              "Preserved existing #{inspect(module)}; review its policies and integration contract."
            )
          else
            Igniter.Project.Module.create_module(acc, module, body)
          end

        add_resource_reference(acc, options.domain, module)
      end)
    end

    defp add_resource_reference(igniter, domain, resource) do
      # Inspect the source directly. A newly generated/uncompiled host domain
      # need not yet be present in the running Mix project's domain registry.
      Igniter.Project.Module.find_and_update_module!(igniter, domain, fn zipper ->
        exists =
          Igniter.Code.Common.move_to(zipper, fn cursor ->
            Igniter.Code.Function.function_call?(cursor, :resource, [1, 2]) &&
              Igniter.Code.Function.argument_equals?(cursor, 0, resource)
          end)

        case exists do
          {:ok, _cursor} ->
            {:ok, zipper}

          :error ->
            case Igniter.Code.Function.move_to_function_call_in_current_scope(
                   zipper,
                   :resources,
                   1
                 ) do
              {:ok, resources} ->
                with {:ok, body} <- Igniter.Code.Common.move_to_do_block(resources) do
                  {:ok, Igniter.Code.Common.add_code(body, "resource #{inspect(resource)}")}
                end

              :error ->
                {:ok,
                 Igniter.Code.Common.add_code(
                   zipper,
                   "resources do\n resource #{inspect(resource)}\nend"
                 )}
            end
        end
      end)
    end

    defp resource_header(options, fragments, table, extra_options \\ []) do
      extra =
        Enum.map_join(extra_options, "\n", fn {key, value} -> "#{key}: #{inspect(value)}," end)

      """
      use Ash.Resource,
        otp_app: #{inspect(options.app)},
        domain: #{inspect(options.domain)},
        data_layer: AshPostgres.DataLayer,
        authorizers: [Ash.Policy.Authorizer],
        #{extra}
        fragments: [#{Enum.join(fragments, ", ")}]

      postgres do
        table #{inspect(options.app_key <> "_korero_" <> table)}
        repo #{inspect(options.repo)}
      end
      """
    end

    defp task_body(options, message?) do
      fragments = if message?, do: ["Korero.Task", "Korero.Message"], else: ["Korero.Task"]
      table = if message?, do: "messages", else: "tasks"

      message_sections =
        if message? do
          """
          code_interface do
            define :compose
          end

          actions do
            create :compose do
              accept [:title, :description, :subject, :distribution_keys]
            end
          end
          """
        else
          ""
        end

      message_change =
        if message?, do: "change set_attribute(:task_type, \"message\"), on: :create", else: ""

      resource_header(options, fragments, table) <>
        """
        #{message_sections}

        code_interface do
          define :inbox
        end

        actions do
          read :inbox do
            pagination keyset?: true, offset?: true, required?: false, default_limit: 25, max_page_size: 100
            prepare build(sort: [inserted_at: :desc, id: :desc])
          end
        end

        relationships do
          belongs_to :owner, #{inspect(options.user)} do
            allow_nil? false
            attribute_writable? false
          end
        end

        changes do
          change relate_actor(:owner), on: :create
          change after_action(&__MODULE__.verify_request_owner/3), on: :create
          #{message_change}
        end

        @doc false
        def verify_request_owner(_changeset, %{owner_id: owner_id} = record, %{actor: %{id: actor_id}})
            when owner_id == actor_id, do: {:ok, record}

        def verify_request_owner(_changeset, _record, _context),
          do: {:error, "task request identity belongs to another owner"}

        policies do
          policy action_type(:create) do
            authorize_if relating_to_actor(:owner)
          end

          policy action_type([:read, :update, :destroy]) do
            authorize_if expr(owner_id == ^actor(:id))
          end
        end
        """
    end

    defp channel_body(options) do
      resource_header(options, ["Korero.Channel"], "channels", primary_read_warning?: false) <>
        """
        @behaviour Korero.Scope

        @impl true
        def korero_app_key, do: #{inspect(options.app_key)}

        relationships do
          belongs_to :user, #{inspect(options.user)} do
            source_attribute :user_id
            define_attribute? false
          end
        end

        policies do
          policy action_type(:create) do
            authorize_if relating_to_actor(:user)
          end

          policy action_type([:read, :update, :destroy]) do
            authorize_if expr(user_id == ^actor(:id) and app_key == #{inspect(options.app_key)})
          end
        end
        """
    end

    defp filing_body(options, fragment) do
      table = Macro.underscore(fragment) <> "s"

      references =
        if fragment == "InboxItemState" do
          """
          changes do
            change before_action(&__MODULE__.authorize_references/2), on: [:create, :update]
          end

          @doc false
          def authorize_references(changeset, context) do
            source_kind = Ash.Changeset.get_attribute(changeset, :source_kind)
            source_id = Ash.Changeset.get_attribute(changeset, :source_id)
            folder_id = Ash.Changeset.get_attribute(changeset, :folder_id)

            # This trusted registry is deliberately local and static. Extend it
            # with explicit authorized host resources, never module-from-string dispatch.
            source = Map.get(%{"task" => #{inspect(options.domain)}.Task, "message" => #{inspect(options.domain)}.Message}, source_kind)

            with true <- not is_nil(source),
                 {:ok, source_id} <- Ash.Type.cast_input(:uuid, source_id),
                 {:ok, %{id: ^source_id}} <- Ash.get(source, source_id, actor: context.actor, tenant: context.tenant, authorize?: true),
                 :ok <- authorize_folder(folder_id, context) do
              changeset
            else
              _forbidden -> Ash.Changeset.add_error(changeset, "filing requires an authorized source and personal folder")
            end
          end

          defp authorize_folder(nil, _context), do: :ok

          defp authorize_folder(folder_id, context) do
            case Ash.get(#{inspect(options.domain)}.InboxFolder, folder_id,
                   actor: context.actor, tenant: context.tenant, authorize?: true) do
              {:ok, %{id: ^folder_id}} -> :ok
              _forbidden -> {:error, :forbidden_folder}
            end
          end
          """
        else
          ""
        end

      resource_header(options, ["Korero." <> fragment], table) <>
        """
        relationships do
          belongs_to :user, #{inspect(options.user)} do
            source_attribute :user_id
            define_attribute? false
          end
        end

        policies do
          policy action_type(:create) do
            authorize_if relating_to_actor(:user)
          end

          policy action_type([:read, :update, :destroy]) do
            authorize_if expr(user_id == ^actor(:id))
          end
        end

        #{references}
        """
    end

    defp configure(igniter, options) do
      igniter
      |> Igniter.Project.Config.configure(
        "config.exs",
        options.app,
        [:ash_domains],
        [options.domain],
        updater: &Igniter.Code.List.prepend_new_to_list(&1, options.domain)
      )
      |> Igniter.Project.Config.configure_new("config.exs", :tag_ash, [:repo], options.repo)
      |> Igniter.Project.Config.configure("config.exs", :tag_ash, [:ash_domains], [TagAsh.Domain],
        updater: &Igniter.Code.List.prepend_new_to_list(&1, TagAsh.Domain)
      )
      |> Igniter.add_notice(
        "Channel and classifier configuration are user/application-scoped. No provider, credential, direct TagAsh authorization policy, or message delivery was inferred."
      )
    end

    defp install_route(igniter, %{live_view: nil}) do
      Igniter.add_notice(
        igniter,
        "No Inbox route installed. Supply --live-view with the existing shared-client host module and --on-mount with its authenticated host hook."
      )
    end

    defp install_route(igniter, options) do
      {:ok, {igniter, _source, zipper}} =
        Igniter.Project.Module.find_module(igniter, options.router)

      existing =
        Igniter.Code.Common.move_to(zipper, fn cursor ->
          Igniter.Code.Function.function_call?(cursor, :live, [2, 3]) &&
            Igniter.Code.Function.argument_equals?(cursor, 0, options.path)
        end)

      case existing do
        {:ok, cursor} ->
          if Igniter.Code.Function.argument_equals?(cursor, 1, options.live_view) &&
               authenticated_ancestor?(cursor, options.hook) do
            igniter
          else
            Igniter.add_issue(
              igniter,
              "The requested path #{options.path} already has a different or unverified authentication contract. Existing routes were preserved; review the conflict."
            )
          end

        :error ->
          session =
            Igniter.Code.Common.move_to(zipper, fn cursor ->
              Igniter.Code.Function.function_call?(cursor, :live_session, [2, 3]) &&
                Igniter.Code.Function.argument_equals?(cursor, 0, :korero_inbox)
            end)

          if match?({:ok, _}, session) do
            Igniter.add_issue(
              igniter,
              "Korero's Inbox live_session already exists at a different path. Existing routing was preserved; update it deliberately."
            )
          else
            Igniter.Libs.Phoenix.add_scope(
              igniter,
              "/",
              """
              pipe_through :browser

              live_session :korero_inbox, on_mount: [{#{inspect(options.hook.module)}, :#{options.hook.argument}}] do
                live #{inspect(options.path)}, #{inspect(options.live_view)}, :index
              end
              """,
              router: options.router,
              placement: :after
            )
          end
      end
    end

    defp authenticated_ancestor?(nil, _hook), do: false

    defp authenticated_ancestor?(cursor, hook) do
      if Igniter.Code.Function.function_call?(cursor, :live_session, [2, 3]) do
        expected = Sourceror.parse_string!("[{#{inspect(hook.module)}, :#{hook.argument}}]")

        with {:ok, argument} <- Igniter.Code.Function.move_to_nth_argument(cursor, 1),
             {:ok, on_mount} <- Igniter.Code.Keyword.get_key(argument, :on_mount) do
          Sourceror.to_string(on_mount.node) == Sourceror.to_string(expected)
        else
          _missing -> false
        end
      else
        authenticated_ancestor?(Sourceror.Zipper.up(cursor), hook)
      end
    end

    defp sources(igniter) do
      Map.new(igniter.rewrite.sources, fn {path, source} ->
        {path, Rewrite.Source.get(source, :content)}
      end)
    end

    defp changed_since?(igniter, original_sources) do
      Enum.any?(igniter.rewrite.sources, fn {path, source} ->
        case Map.fetch(original_sources, path) do
          {:ok, content} -> Rewrite.Source.get(source, :content) != content
          # Codemods also load existing formatter/configuration files. Loading
          # an unchanged file is not a reason to regenerate database migrations.
          :error -> Igniter.changed?(source)
        end
      end)
    end
  end
else
  defmodule Mix.Tasks.Korero.Install do
    use Mix.Task
    @shortdoc "Install Korero into a host (requires Igniter)"

    @impl true
    def run(_argv) do
      Mix.raise(
        "korero.install requires Igniter. Add {:igniter, \"~> 0.8.4\", only: :dev, runtime: false} to the host dependencies."
      )
    end
  end
end
