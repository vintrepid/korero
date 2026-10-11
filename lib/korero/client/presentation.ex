defmodule Korero.Client.Presentation do
  @moduledoc "Resource-owned projection contract extracted from Calvin's InboxPresentation."
  @callback present_inbox(struct(), map()) :: map()

  def present(%{__struct__: resource} = record, context) do
    resource.present_inbox(record, context)
  end
end
