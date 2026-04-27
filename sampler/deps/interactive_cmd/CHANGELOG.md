<!--
  SPDX-FileCopyrightText: None
  SPDX-License-Identifier: CC0-1.0
-->

# Changelog

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.1.4

* Changes
  * Fixed script argument order error introduced around util-linux 2.42. Thanks
    to @CJRChang.

## v0.1.3

* Changes
  * Add `:log_path` for logging stdout (not stdin). Logging happens outside of
    Erlang via the `script(1)` command. This is useful for capturing output from
    long build tasks.

## v0.1.2

* Changes
  * Add `shell/2` to avoid needing to manually call `sh -c` when updating calls
    to `System.shell/2`.

## v0.1.1

* Changes
  * Improve `:user_drv` detection to prevent running on group leaders that
    don't use `:user_drv` and therefore won't work

## v0.1.0

Initial release

