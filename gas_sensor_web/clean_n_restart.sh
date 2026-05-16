#!/bin/bash

# This setup is only valid when testing and developing
# this app by itself
# make sure that you include gas_sensor otp app as
# a dependency in the mix file 
rm -rf _build
rm -rf deps
rm -rf priv/static/assets
export MIX_TARGET=host
cd "./assets"
npm install
cd "../"
mix deps.get
mix assets.build
mix assets.deploy
#mix deps.compile --force
#mix deps.compile gas_sensor --force
iex -S mix phx.server
