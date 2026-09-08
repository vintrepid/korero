defmodule Inbox.Test.Task do
  @moduledoc false

  use Ash.Resource,
    domain: Inbox.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Inbox.Test.EtsIdentities],
    fragments: [Inbox.Task]

  ets do
    private? true
  end
end

defmodule Inbox.Test.ProtectedTask do
  @moduledoc false

  use Ash.Resource,
    domain: Inbox.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Inbox.Test.EtsIdentities],
    fragments: [Inbox.Task]

  ets do
    private? true
  end

  policies do
    policy always() do
      authorize_if actor_attribute_equals(:role, :operator)
    end
  end
end

defmodule Inbox.Test.JobTask do
  @moduledoc false

  use Ash.Resource,
    domain: Inbox.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Inbox.Test.EtsIdentities],
    fragments: [Inbox.Task]

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
        queue :inbox
        worker_module_name Inbox.Test.StartMachineWorker
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

defmodule Inbox.Test.Domain do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource Inbox.Test.Task
    resource Inbox.Test.ProtectedTask
    resource Inbox.Test.JobTask
  end
end
