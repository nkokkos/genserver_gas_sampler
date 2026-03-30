defmodule GasSensorWeb.ErrorHTML do
  @moduledoc """
  HTML error pages.
  """
  use GasSensorWeb, :html

  def render("404.html", _assigns) do
    "Page not found"
  end

  def render("500.html", _assigns) do
    "Internal server error"
  end

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
