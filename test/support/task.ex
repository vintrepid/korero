defmodule Korero.Test.Task do
  @moduledoc false

  use Ash.Resource,
    domain: Korero.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Korero.Test.EtsIdentities],
    fragments: [Korero.Task]

  ets do
    private? true
  end
end

defmodule Korero.Test.ProtectedTask do
  @moduledoc false

  use Ash.Resource,
    domain: Korero.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Korero.Test.EtsIdentities],
    fragments: [Korero.Task]

  ets do
    private? true
  end

  policies do
    policy always() do
      authorize_if actor_attribute_equals(:role, :operator)
    end
  end
end

defmodule Korero.Test.JobTask do
  @moduledoc false

  use Ash.Resource,
    domain: Korero.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Korero.Test.EtsIdentities],
    fragments: [Korero.Task]

  ets do
    private? true
  end

  actions do
    read :runnable do
      pagination keyset?: true, required?: false
    end
  end

  oban do
    triggers do
      trigger :start_machine do
        action :start
        read_action :runnable
        worker_read_action :read

        where expr(
                task_type == "machine_job" and status == :queued and
                  is_nil(target_resource) and is_nil(target_key)
              )

        scheduler_cron false
        queue :korero
        worker_module_name Korero.Test.StartMachineWorker
        default_actor %{role: :queue_worker}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :operator)
      authorize_if actor_attribute_equals(:role, :queue_worker)
    end

    policy action(:create) do
      authorize_if actor_attribute_equals(:role, :operator)
    end

    policy action(:start) do
      authorize_if actor_attribute_equals(:role, :queue_worker)
    end
  end
end

defmodule Korero.Test.Message do
  @moduledoc false

  use Ash.Resource,
    domain: Korero.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    fragments: [Korero.Message]

  ets do
    private? true
  end

  actions do
    defaults [:read, create: [:content, :subject, :distribution_keys]]
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :content, :string, allow_nil?: false, public?: true
  end
end

defmodule Korero.Test.Domain do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource Korero.Test.Task
    resource Korero.Test.ProtectedTask
    resource Korero.Test.JobTask
    resource Korero.Test.Message
  end
end
