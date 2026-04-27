# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule InteractiveCmd do
  @moduledoc """
  Run interactive shell commands from mostly pure Elixir
  """

  @typedoc """
  Options for `cmd/3`
  """
  @type options() :: [env: Enumerable.t(), cd: String.t(), log_path: String.t()]

  @doc """
  Executes the given command with args interactively

  This shell will take over the terminal so that it's possible for the user to
  interact with whatever program is run. All input is sent to the command
  including CTRL+C. This allows you to invoke interactive commands like those
  that request passwords, prompt for input, or show an interactive text-based
  UI.

  This uses `:user_drv` internally so it only works at the startup console or
  other consoles that use it.

  Options:
  * `:env` - a map of string key/value pairs to be put into the environment.
    See `System.put_env/1`.
  * `:cd` - the directory to run the command in. See `System.cmd/3`.
  * `:log_path` - if specified, all output is logged to this file. Defaults to
    `/dev/null`

  Returns `{"", exit_status}` where the first element is always an empty string
  and the second is the exit status of the command. This return value is
  intentionally similar to `System.cmd/3` to allow `InteractiveCmd,cnd/3` to be
  swapped in quickly when needed.
  """
  @spec cmd(binary(), [binary()], options()) :: {binary(), exit_status :: non_neg_integer()}
  def cmd(command, args, options \\ []) do
    quoted_command = Enum.map_join([command | args], " ", &shell_quote/1)
    shell(quoted_command, options)
  end

  @doc """
  Executes the given command interactively

  It uses `sh` to evaluate the command.

  > #### Watch out {: .warning}
  >
  > Use this function with care. In particular, **never pass untrusted user input
  > to this function**, as the user would be able to perform "command injection
  > attacks" by executing any code directly on the machine. Generally speaking,
  > prefer to use `cmd/3` over this function.

  See `cmd/3` for more information and options.
  """
  @spec shell(binary(), options()) :: {binary(), exit_status :: non_neg_integer()}
  def shell(command, options \\ []) do
    ensure_user_drv()

    original_env = System.get_env()
    original_dir = File.cwd!()

    if cd = Keyword.get(options, :cd) do
      File.cd!(cd)
    end

    log_path =
      case Keyword.get(options, :log_path) do
        nil -> "/dev/null"
        path -> Path.expand(path)
      end

    flavor = script_flavor()

    System.put_env(Keyword.get(options, :env, %{}))
    System.put_env("INTERACTIVE_CMD_COMMAND", command)
    System.put_env("INTERACTIVE_CMD_LOG_PATH", log_path)
    System.put_env("VISUAL", launcher_command(flavor))

    send(:user_drv, {self(), {:open_editor, ""}})

    result =
      receive do
        {_pid, {:editor_data, output}} -> output
      end

    if log_path != "/dev/null" and adds_log_header(flavor) do
      strip_script_headers(log_path)
    end

    File.cd!(original_dir)
    restore_env(original_env)
    {"", parse_exit_status(result)}
  end

  defp script_flavor() do
    case :os.type() do
      {:unix, :linux} -> :gnu
      {:unix, _bsd} -> :bsd
    end
  end

  # $1 is the results filename from user_drv
  defp launcher_command(:gnu) do
    # -c needs to come before -q in util-linux 2.42.
    # https://github.com/util-linux/util-linux/issues/4257
    ~s(sh -c 'stty opost;script -e -c "$INTERACTIVE_CMD_COMMAND" -q "$INTERACTIVE_CMD_LOG_PATH"; echo $? > "$1"' sh)
  end

  defp launcher_command(:bsd) do
    ~s(sh -c 'stty opost;script -q "$INTERACTIVE_CMD_LOG_PATH" sh -c "$INTERACTIVE_CMD_COMMAND"; echo $? > "$1"' sh)
  end

  # GNU script (util-linux >= 2.35) always writes header and trailer
  defp adds_log_header(:gnu), do: true
  defp adds_log_header(:bsd), do: false

  defp strip_script_headers(path) do
    tmp_path = path <> ".tmp"
    out = File.stream!(tmp_path)
    File.stream!(path) |> trim_first_and_last_lines() |> Stream.into(out) |> Stream.run()
    File.rm!(path)
    File.rename!(tmp_path, path)
  end

  @doc false
  @spec trim_first_and_last_lines(Enumerable.t()) :: Enumerable.t()
  def trim_first_and_last_lines(lines) do
    lines
    |> Stream.drop(1)
    |> Stream.transform(
      fn -> :empty end,
      fn
        line, :empty -> {[], [line]}
        line, [a] -> {[], [a, line]}
        line, [a, b] -> {[a], [b, line]}
      end,
      fn
        ["\n", _] -> {[], []}
        [a, _] -> {[String.replace_suffix(a, "\n", "")], []}
        _ -> {[], []}
      end,
      &Function.identity/1
    )
  end

  defp restore_env(original) do
    env = System.get_env()
    System.put_env(original)

    to_delete = Map.keys(env) -- Map.keys(original)
    Enum.each(to_delete, &System.delete_env/1)
  end

  defp shell_quote(str), do: "'#{escape_quote(str)}'"
  defp escape_quote(str), do: String.replace(str, "'", "'\\''")

  defp parse_exit_status(output) when is_list(output) do
    trimmed = output |> to_string() |> String.trim()

    case Integer.parse(trimmed) do
      {status, ""} when status >= 0 -> status
      _ -> 255
    end
  end

  defp ensure_user_drv() do
    with {:error, reason} <- user_drv_ok() do
      raise RuntimeError, reason
    end
  end

  @doc """
  Check if `cmd/3` should work

  Returns `:ok` if it looks like the requirements are met. An error tuple is
  returned if not. The caller can either implement a fallback or show the user
  the error message.
  """
  @spec check_requirements() :: :ok | {:error, String.t()}
  def check_requirements() do
    with :ok <- platform_ok(),
         :ok <- user_drv_ok(),
         :ok <- has_executable("script") do
      has_executable("stty")
    end
  end

  defp platform_ok() do
    case :os.type() do
      {:unix, :darwin} -> :ok
      {:unix, :linux} -> :ok
      other -> {:error, "Unsupported platform: #{inspect(other)}"}
    end
  end

  defp has_executable(program) do
    case System.find_executable(program) do
      nil -> {:error, "Required program not found: #{program}"}
      _ -> :ok
    end
  end

  defp user_drv_ok() do
    gl = Process.group_leader()
    parent_gl = parent(gl)
    user_drv = Process.whereis(:user_drv)

    cond do
      user_drv == nil -> {:error, "This is not an interactive session. :user_drv not running"}
      user_drv != parent_gl -> {:error, "Must be running on the startup console"}
      true -> :ok
    end
  end

  defp parent(pid) do
    with {:parent, p} <- Process.info(pid, :parent), do: p
  end
end
