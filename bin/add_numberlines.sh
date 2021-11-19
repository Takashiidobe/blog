#!/usr/bin/env bash

sed -i -E 's/```([a-z]+)/```\{\.\1 \.numberLines\}/g' posts/*.md
