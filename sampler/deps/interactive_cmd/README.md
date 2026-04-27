<!--
  SPDX-FileCopyrightText: 2025 Frank Hunleth
  SPDX-License-Identifier: CC-BY-4.0
-->

# InteractiveCmd

[![Hex version](https://img.shields.io/hexpm/v/interactive_cmd.svg "Hex version")](https://hex.pm/packages/interactive_cmd)
[![API docs](https://img.shields.io/hexpm/v/interactive_cmd.svg?label=hexdocs "API docs")](https://hexdocs.pm/interactive_cmd/InteractiveCmd.html)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/fhunleth/interactive_cmd/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/fhunleth/interactive_cmd/tree/main)
[![REUSE status](https://api.reuse.software/badge/github.com/fhunleth/interactive_cmd)](https://api.reuse.software/info/github.com/fhunleth/interactive_cmd)

Run interactive shell commands from mostly pure Elixir

This addresses an issue when writing commandline scripts that need to invoke
commands that require user input. Examples include commands that ask for
passwords like `ssh` and `sudo`, menu-driven commands, and launching text
editors.

This library works by using Erlang's command line editor feature launches an
editor to provide input to the shell prompt. You can try this by typing Ctrl-o
or Meta-o at the IEx prompt assuming your OS doesn't already have a mapping for
that key combination. Since this functionality isn't provided by a public API,
standard caveats apply. Luckily, this works in quite a few OTP releases. This
library also verifies that it works in CI. The main limitation is that it only
works when the process group leader is backed by `:user_drv`. For scripting,
this is not much of a limitation, but it wouldn't work when using Erlang's `ssh`
server, for example. Huge thanks to [ieQu1 on the Erlang
Forum](https://erlangforums.com/t/entering-raw-mode-temporarily-while-in-the-shell-for-a-tui/5120/5)
for the original idea.

Using this is simply replacing your calls to `System.cmd/3` or `System.shell/2`
with the similarly named ones in `InteractiveCmd`. Output capture options are
ignored.

## Example

Here's an example of using `InteractiveCmd.cmd/3` to let a user run commands in
a Docker container created by an Elixir script.

![InteractiveCmd Demo](demo/docker_demo.gif)

## Installation and use

`InteractiveCmd` only works on macOS and Linux.

The package can be installed by adding `interactive_cmd` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:interactive_cmd, "~> 0.1.0"}
  ]
end
```

You will also need the `stty` and `script` utilities available on macOS and
Linux. These are usually already installed. If using on a minimal Linux image,
you may need to install `util-linux`.

Then in your code, do something like this on macOS:

```elixir
# macOS version
iex> InteractiveCmd.shell("brew install nsnake")
...
✔︎ Bottle nsnake (3.0.1)                             [Downloaded  123.2KB/123.2KB]
==> Pouring nsnake--3.0.1.arm64_tahoe.bottle.1.tar.gz
{"", 0}
```

or on Linux:

```elixir
iex> InteractiveCmd.shell("sudo apt install nsnake")
[sudo] password for fhunleth:
Reading package lists... Done
Building dependency tree... Done
...
{"", 0}
```

The final line is a tuple with the output and exit status, like you'd get from
`System.shell/2`. Unlike `System.shell/2`, output is not captured and is instead
streamed directly to the terminal, so the first element is always an empty
string.

Now run the program you just installed:

```elixir
iex> nsnake = "nsnake" # set to "/usr/games/nsnake" on Linux
iex> InteractiveCmd.cmd("nsnake", [])
...
```

## Troubleshooting

Since this repurposes an Erlang shell feature, this library could break on newer
Erlang versions. Please check the Erlang versions tested on
[CI](https://github.com/fhunleth/interactive_cmd/blob/main/.circleci/config.yml)
to see which ones are expected to work.

Next, try running your command via `System.cmd/3` to see if you get a better
error message. If you get a better error message, please file an issue or send a
PR to help others in the future.

If all else fails, file an issue with details about your system and the command
you're trying to run. It will be super helpful if there's some way I can
reproduce it.

## FAQ

1. Can I use this in Escripts or Mix archives?

Yes. The implementation is one Elixir module with no native code. If you're
writing a Mix archive, just copy `interactive_cmd.ex` to your project and rename
the module name to vendor it.

2. What about security?

The normal caveats apply to running shell commands so be sure to scrub any
untrusted sources. Additionally, `InteractiveCmd.cmd/3` doesn't directly run the
executable like `System.cmd/3` does, so it's more susceptable to injection
attacks than may be obvious. I've taken precautions to escape strings so easy
injection attacks shouldn't work. If your use case is susceptible to malicious
users, please take normal precautions.

3. Could this be rewritten in Erlang so that it could be used in other
   BEAM languages?

Yes. This totally makes sense as a pure Erlang library. I didn't think about it
until I was almost done. It seems easy to do. If this interests you and you have
time to help verify and add instructions to the README, please file an issue.
