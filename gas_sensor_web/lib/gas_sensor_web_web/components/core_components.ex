defmodule GasSensorWeb.CoreComponents do
  @moduledoc """
  Core UI components for the Gas Sensor Web application.

  Provides minimal essential components for embedded deployment.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.
  """
  attr(:id, :string, doc: "the optional id of flash container")
  attr(:flash, :map, required: true, doc: "the flash message")
  attr(:title, :string, default: nil)
  attr(:kind, :atom, values: [:info, :error], required: true)
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the flash container")

  slot(:inner_block, doc: "the optional inner block that renders the flash message")

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 w-80 sm:w-96 z-50 rounded-lg p-4 shadow-lg",
        @kind == :info && "bg-green-50 text-green-800 ring-green-500",
        @kind == :error && "bg-red-50 text-red-800 ring-red-500"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 font-semibold">
        <%= @title %>
      </p>
      <p class="mt-2 text-sm"><%= msg %></p>
      <button type="button" class="absolute top-2 right-2">×</button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr(:flash, :map, required: true, doc: "the flash messages")

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} title="Success!" flash={@flash} />
    <.flash kind={:error} title="Error!" flash={@flash} />
    """
  end

  # JS command for hiding elements
  defp hide(js, selector) do
    JS.hide(js, to: selector, transition: "fade-out")
  end
end
