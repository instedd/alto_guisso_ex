defmodule Guisso.Test.User do
  use Ecto.Schema
  use Coherence.Schema
  import Ecto.Changeset

  schema "users" do
    coherence_schema()
    field :email, :string
    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:email])
  end

  def insert(email) do
    __MODULE__.__struct__
    |> changeset(%{email: email})
    |> Coherence.Config.repo.insert!
  end
end
