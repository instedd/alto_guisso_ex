defmodule Guisso.Test.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Phoenix.ConnTest
      import Plug.Conn
    end
  end

  setup tags do
    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.checkout(Guisso.Test.Repo)
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
