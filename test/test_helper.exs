ExUnit.start()

Code.require_file "./support/conn_case.exs", __DIR__
Code.require_file "./support/schema.exs", __DIR__
Code.require_file "./support/repo.exs", __DIR__
Code.require_file "./support/migrations.exs", __DIR__

Guisso.Test.Repo.__adapter__.storage_down Guisso.Test.Repo.config
Guisso.Test.Repo.__adapter__.storage_up Guisso.Test.Repo.config

Guisso.Test.Repo.start_link
Ecto.Migrator.up(Guisso.Test.Repo, 0, Guisso.Test.Migrations, log: false)

Ecto.Adapters.SQL.Sandbox.mode(Guisso.Test.Repo, :manual)
